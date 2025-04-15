// Copyright 2017 ETH Zurich and University of Bologna.
// -- Adaptable modifications made for hbirdv2 SoC. -- 
// -- Adaptable modifications made for uart_test_env. --
// Copyright 2020 Nuclei System Technology, Inc.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module uart_tx #(
    parameter [15:0] CFG_BAUD_DIV    = 'h55,
    parameter [ 2:0] CFG_TARGET_BITS = 'h7 ,
    parameter [ 0:0] CFG_PARITY_EN   = 'b0 ,
    parameter [ 1:0] CFG_PARITY_SEL  = 'h0 ,
    parameter [ 0:0] CFG_STOP_BITS   = 'b0 
)(
    input  wire        clk_i        ,
    input  wire        rstn_i       ,
    output reg         tx_o         ,
    output wire        busy_o       ,

    input  wire [7:0]  tx_data_i    ,
    input  wire        tx_valid_i   ,
    output reg         tx_ready_o
);

// input wire         cfg_en_i        , // cfg enable signal
// input  wire [15:0] cfg_div_i       , // baudrate div value : f_clk / baudrate
// input  wire        cfg_parity_en_i , // parity enable
// input  wire [1:0]  cfg_parity_sel_i, // parity select : 00->even, 01->odd, 02:none, 11: reversed
// input  wire [1:0]  cfg_bits_i      , // data bits length: 00->5, 01->6, 10->7, 11->8
// input  wire        cfg_stop_bits_i , // stop bits length: 0->1bit, 1->2bits
localparam [2:0] IDLE           = 0;
localparam [2:0] START_BIT      = 1;
localparam [2:0] DATA           = 2;
localparam [2:0] PARITY         = 3;
localparam [2:0] STOP_BIT_FIRST = 4;
localparam [2:0] STOP_BIT_LAST  = 5;

reg [2:0]  CS,NS;
   
reg [7:0]  reg_data          ;
reg [7:0]  reg_data_next     ;
reg [2:0]  reg_bit_count     ;
reg [2:0]  reg_bit_count_next;

reg        parity_bit        ;
reg        parity_bit_next   ;

reg        sampleData        ;

reg [15:0] baud_cnt          ;
reg        baudgen_en        ;
reg        bit_done          ;

assign busy_o = (CS != IDLE);

always @(*) begin
    NS                 = CS;
    tx_o               = 1'b1;
    sampleData         = 1'b0;
    reg_bit_count_next = reg_bit_count;
    reg_data_next      = {1'b1, reg_data[7:1]};
    tx_ready_o         = 1'b0;
    baudgen_en         = 1'b0;
    parity_bit_next    = parity_bit;

    case (CS)
    IDLE: begin
        tx_ready_o = 1'b1;
        if (tx_valid_i) begin
            NS            = START_BIT;
            sampleData    = 1'b1;
            reg_data_next = tx_data_i;
        end
    end
    START_BIT: begin
        tx_o            = 1'b0;
        parity_bit_next = 1'b0;
        baudgen_en      = 1'b1;
        if (bit_done)
            NS = DATA;
    end
    DATA: begin
        tx_o            = reg_data[0];
        baudgen_en      = 1'b1;
        parity_bit_next = parity_bit ^ reg_data[0];

        if (bit_done) begin
            if (reg_bit_count == CFG_TARGET_BITS) begin
                reg_bit_count_next = 'h0;
                if (CFG_PARITY_EN)
                    NS = PARITY;
                else
                    NS = STOP_BIT_FIRST;
            end else begin
                reg_bit_count_next = reg_bit_count + 1;
                sampleData         = 1'b1;
            end
        end
    end
    PARITY: begin
        case (CFG_PARITY_SEL)
            2'b00: tx_o = ~parity_bit;
            2'b01: tx_o = parity_bit;
            2'b10: tx_o = 1'b0;
            2'b11: tx_o = 1'b1;
        endcase

        baudgen_en = 1'b1;

        if (bit_done)
            NS = STOP_BIT_FIRST;
    end
    STOP_BIT_FIRST: begin
        tx_o       = 1'b1;
        baudgen_en = 1'b1;

        if (bit_done) begin
            if (CFG_STOP_BITS)
                NS = STOP_BIT_LAST;
            else
                NS = IDLE;
        end
    end
    STOP_BIT_LAST: begin
        tx_o = 1'b1;
        baudgen_en = 1'b1;
        if (bit_done)
            NS = IDLE;
    end
    default: NS = IDLE;
    endcase
end


always @(posedge clk_i or negedge rstn_i) begin
    if (rstn_i == 1'b0) begin
        CS            <= IDLE;
        reg_data      <= 8'hff;
        reg_bit_count <= 'h0;
        parity_bit    <= 1'b0;
    end else begin
        if (bit_done)
            parity_bit <= parity_bit_next;
        if (sampleData)
            reg_data   <= reg_data_next;

        reg_bit_count  <= reg_bit_count_next;
        
        CS <= NS;
    end
end

always @(posedge clk_i or negedge rstn_i) begin
    if (rstn_i == 1'b0) begin
        baud_cnt <= 'h0;
        bit_done <= 1'b0;
    end else if (baudgen_en) begin
        if (baud_cnt == CFG_BAUD_DIV) begin
            baud_cnt <= 'h0;
            bit_done <= 1'b1;
        end
        else begin
            baud_cnt <= baud_cnt + 1;
            bit_done <= 1'b0;
        end
end else begin
        baud_cnt <= 'h0;
        bit_done <= 1'b0;
    end
end

//synopsys translate_off
always @(posedge clk_i or negedge rstn_i) begin
    if ((tx_valid_i & tx_ready_o) & rstn_i)
        $fwrite(32'h80000002, "%c", tx_data_i);
end
//synopsys translate_on    

endmodule
