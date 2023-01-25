module TPU(
    clk,
    rst_n,

    in_valid,
    K,
    M,
    N,
    busy,

    A_wr_en,
    A_index,
    A_data_in,
    A_data_out,

    B_wr_en,
    B_index,
    B_data_in,
    B_data_out,

    C_wr_en,
    C_index,
    C_data_in,
    C_data_out
);


input clk;
input rst_n;
input            in_valid;
input [7:0]      K;
input [7:0]      M;
input [7:0]      N;
output  reg      busy ;

output           A_wr_en;
output [15:0]    A_index;
output [31:0]    A_data_in;
input  [31:0]    A_data_out;

output           B_wr_en;
output [15:0]    B_index;
output [31:0]    B_data_in;
input  [31:0]    B_data_out;

output           C_wr_en;
output [15:0]    C_index;
output [127:0]   C_data_in;
input  [127:0]   C_data_out;




//* Implement your design here

parameter IDLE = 2'd0;
parameter READ = 2'd1;
parameter OUTPUT = 2'd2;
parameter FINISH = 2'd3;

reg [15:0] mula_temp [0:15];
reg [15:0] mulb_temp [0:15];
reg [31:0] psum_temp [0:15];
     
reg [7:0] a1_temp;
reg [7:0] a2_temp [0:1];
reg [7:0] a3_temp [0:2];
reg [7:0] a4_temp [0:3];
     
reg [7:0] b1_temp;
reg [7:0] b2_temp [0:1];
reg [7:0] b3_temp [0:2];
reg [7:0] b4_temp [0:3];

reg [15:0] mul [0:15];

reg [1:0] state, n_state;
reg [7:0] row_offset;
reg [7:0] col_offset;
reg [7:0] counter_a;
reg [7:0] counter_b;
reg [31:0] counter;
reg [31:0] counter_out;
reg [15:0] index_a;
reg [15:0] index_b;
reg [15:0] index_c;
reg           A_wr_en_r;
reg [15:0]    A_index_r;
reg [31:0]    A_data_in_r;

reg           B_wr_en_r;
reg [15:0]    B_index_r;
reg [31:0]    B_data_in_r; 

reg           C_wr_en_r;
reg [15:0]    C_index_r;
reg [127:0]   C_data_in_r;

reg [2:0] out_limit;

reg [7:0]      K_tmp;
reg [7:0]      M_tmp;
reg [7:0]      N_tmp;

integer i;

// -------------------State Machine--------------------//

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) state <= IDLE;
    else state <= n_state;
  end

  always @(*) begin
    case (state)
      IDLE: n_state = (in_valid || busy) ? READ : IDLE;
      READ: n_state = (counter <= (K_tmp + 6)) ? READ : OUTPUT;
      OUTPUT: n_state = (counter_out < out_limit) ? OUTPUT : (counter_b == row_offset) ? FINISH : IDLE;
      FINISH: n_state = IDLE;
      default: n_state = IDLE;
    endcase
  end
// ----------------------------------------------------//

// ---------------------Design------------------------//
// offset
  always @(*) begin
    row_offset = ((N_tmp+3)/4)+1;//(N_tmp >= 9) ? 3 : (N_tmp >= 5 && N_tmp < 9) ? 2 : 1;
    col_offset = ((M_tmp+3)/4);//(M_tmp >= 9) ? 2 : (M_tmp >= 5 && M_tmp < 9) ? 1 : 0;
  end

// out_limit
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_limit <= 0;
    else if(state == busy)
      out_limit <= (counter_a == (col_offset-1) && M_tmp[1:0] != 2'b00 ) ? M_tmp[1:0] : 4;
    else
      out_limit <= out_limit;
  end

// wr_en
  assign A_wr_en = 0;
  assign B_wr_en = 0;
  assign C_wr_en = (n_state == OUTPUT)? 1:0;
// K, M, N tmp
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
      K_tmp <= 0;
      M_tmp <= 0;
      N_tmp <= 0;
    end
    if(in_valid)begin
      K_tmp <= K;
      M_tmp <= M;
      N_tmp <= N;
    end
    else if(state == FINISH)begin
      K_tmp <= K_tmp;
      M_tmp <= M_tmp;
      N_tmp <= N_tmp;
    end
  end

// busy
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
      busy <= 0;
    end
    if(in_valid)
      busy <= 1;
    else if(n_state == FINISH)
      busy <= 0;
  end
// counter
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) counter <= 0;
    else begin
      if(state == READ)
        counter <= counter + 1;
      else
        counter <= 0;
    end
  end

// counter_out
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) counter_out <= 0;
    else begin
      if(state == OUTPUT)
        counter_out <= counter_out + 1;
      else
        counter_out <= 0;
    end
  end

// counter_a
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) counter_a <= 0;
    else begin
      if(counter_out == out_limit-1 && state == OUTPUT) begin
        if(counter_a < col_offset)
          counter_a <= counter_a + 1;
        else
          counter_a <= 1;
      end
      else if(state == FINISH)
        counter_a <= 0;
    end
  end

// counter_b
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) counter_b <= 0;
    else begin
      if(n_state == IDLE && counter_a == col_offset && busy)
        counter_b <= counter_b + 1;
      else if(state == FINISH)
        counter_b <= 0;
    end
  end

// buffer index
  assign A_index = index_a;
  assign B_index = index_b;
  assign C_index = (!rst_n)? 0:index_c;

// index_a
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) index_a <= 15'd0;
    else begin
      if(state == OUTPUT) begin
        
        if(K_tmp == 1)
          index_a <= 1;
        else if(n_state==IDLE )begin
          index_a <= index_a + 15'd1;
        end
        else
          index_a <= index_a;
      end
      else if(state == IDLE && counter_a == col_offset)begin
          index_a <= 0;
      end
      else if(state == FINISH)begin
        index_a <= 15'd0;
      end
      else if(state == READ) begin
        if(counter < (K_tmp - 1))
          index_a <= index_a + 15'd1;
      end
      else begin
        index_a <= index_a;
      end
    end
  end
  
// index_b
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) index_b <= 0;
    else begin
      if(state == IDLE && busy) begin
        index_b <= K_tmp * counter_b;
      end
      else if(state == FINISH)begin
        index_b <= 15'd0;
      end
      else if(state == READ) begin
        if(counter < (K_tmp - 1))
          index_b <= index_b + 1;
      end
    end
  end

// index_c
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) index_c <= 0;
    else begin
      if(state == FINISH)
        index_c <= 0;
      else if(state == OUTPUT && n_state == OUTPUT)
        index_c <= index_c + 1;
      else
        index_c <= index_c;
    end
  end
// buffer data in
  assign A_data_in = 0;
  assign B_data_in = 0;

  assign C_data_in = (!rst_n)? 0:{psum_temp[(counter_out << 2) ], psum_temp[(counter_out << 2) + 5'd1], psum_temp[(counter_out << 2) + 5'd2], psum_temp[(counter_out << 2)+5'd3]};
// MUL UNIT
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      for(i = 0; i < 16; i = i + 1)
        mula_temp[i] <= 8'd0;
    end
    else begin
      if(state == READ) begin
        mula_temp[0] <= a1_temp;
        mula_temp[1] <= mula_temp[0];
        mula_temp[2] <= mula_temp[1];
        mula_temp[3] <= mula_temp[2];

        mula_temp[4] <= a2_temp[0];
        mula_temp[5] <= mula_temp[4];
        mula_temp[6] <= mula_temp[5];
        mula_temp[7] <= mula_temp[6];

        mula_temp[8] <= a3_temp[0];
        mula_temp[9] <= mula_temp[8];
        mula_temp[10] <= mula_temp[9];
        mula_temp[11] <= mula_temp[10];

        mula_temp[12] <= a4_temp[0];
        mula_temp[13] <= mula_temp[12];
        mula_temp[14] <= mula_temp[13];
        mula_temp[15] <= mula_temp[14];
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      for(i = 0; i < 16; i = i + 1)
        mulb_temp[i] <= 8'd0;
    end
    else begin
      if(state == READ) begin
        mulb_temp[0] <= b1_temp;
        mulb_temp[4] <= mulb_temp[0];
        mulb_temp[8] <= mulb_temp[4];
        mulb_temp[12] <= mulb_temp[8];

        mulb_temp[1] <= b2_temp[0];
        mulb_temp[5] <= mulb_temp[1];
        mulb_temp[9] <= mulb_temp[5];
        mulb_temp[13] <= mulb_temp[9];

        mulb_temp[2] <= b3_temp[0];
        mulb_temp[6] <= mulb_temp[2];
        mulb_temp[10] <= mulb_temp[6];
        mulb_temp[14] <= mulb_temp[10];

        mulb_temp[3] <= b4_temp[0];
        mulb_temp[7] <= mulb_temp[3];
        mulb_temp[11] <= mulb_temp[7];
        mulb_temp[15] <= mulb_temp[11];
      end
    end
  end
// MUL
  always @(*) begin
    for(i = 0; i < 16; i = i + 1)
      mul[i] = mula_temp[i] * mulb_temp[i];
  end
// PE SUM
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      for(i = 0; i < 16; i = i + 1)
        psum_temp[i] <= 8'd0;
    end
    else begin
      if(state == READ) begin
        for(i = 0; i < 16; i = i + 1)
          psum_temp[i] <= psum_temp[i] + mul[i];
      end
      else if(state == IDLE) begin
        for(i = 0; i < 16; i = i + 1)
          psum_temp[i] <= 8'd0;
      end
    end
  end

// -------------------Data Loader A-------------------//
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) a1_temp <= 0;
    else begin
      if(state == READ) begin
        if(counter < K_tmp)
          a1_temp <= A_data_out[31:24];
        else
          a1_temp <= 0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      for(i = 0; i < 2; i = i + 1)
        a2_temp[i] <= 8'd0;
    end
    else begin
      if(state == READ) begin
        a2_temp[0] <= a2_temp[1];
        if(counter < K_tmp)
          a2_temp[1] <= A_data_out[23:16];
        else
          a2_temp[1] <= 0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      for(i = 0; i < 3; i = i + 1)
        a3_temp[i] <= 8'd0;
    end
    else begin
      if(state == READ) begin
        a3_temp[0] <= a3_temp[1];
        a3_temp[1] <= a3_temp[2];
        if(counter < K_tmp)
          a3_temp[2] <= A_data_out[15:8];
        else
          a3_temp[2] <= 0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      for(i = 0; i < 4; i = i + 1)
        a4_temp[i] <= 8'd0;
    end
    else begin
      if(state == READ) begin
        a4_temp[0] <= a4_temp[1];
        a4_temp[1] <= a4_temp[2];
        a4_temp[2] <= a4_temp[3];
        if(counter < K_tmp)
          a4_temp[3] <= A_data_out[7:0];
        else
          a4_temp[3] <= 0;
      end
    end
  end


// -------------------Data Loader B-------------------//
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) b1_temp <= 0;
    else begin
      if(state == READ)
        if(counter < K_tmp)
          b1_temp <= B_data_out[31:24];
        else
          b1_temp <= 0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      for(i = 0; i < 2; i = i + 1)
        b2_temp[i] <= 8'd0;
    end
    else begin
      if(state == READ) begin
        b2_temp[0] <= b2_temp[1];
        if(counter < K_tmp)
          b2_temp[1] <= B_data_out[23:16];
        else
          b2_temp[1] <= 0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      for(i = 0; i < 3; i = i + 1)
        b3_temp[i] <= 8'd0;
    end
    else begin
      if(state == READ) begin
        b3_temp[0] <= b3_temp[1];
        b3_temp[1] <= b3_temp[2];
        if(counter < K_tmp)
          b3_temp[2] <= B_data_out[15:8];
        else
          b3_temp[2] <= 0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      for(i = 0; i < 4; i = i + 1)
        b4_temp[i] <= 8'd0;
    end
    else begin
      if(state == READ) begin
        b4_temp[0] <= b4_temp[1];
        b4_temp[1] <= b4_temp[2];
        b4_temp[2] <= b4_temp[3];
        if(counter < K_tmp)
          b4_temp[3] <= B_data_out[7:0];
        else
          b4_temp[3] <= 0;
      end
    end
  end





endmodule