/**************************************
@ filename    : axis_fifo.v
@ author      : yyrwkk
@ create time : 2025/04/16 13:30:59
@ version     : v1.0.0
**************************************/


/**************************************
@ filename     : syncfifo.v
@ origin author: xu xiaokang
@ update by    : yyrwkk
@ create time  : 2025/03/28 14:38:08
@ version      : v1.0.0
**************************************/
module syncfifo # (
    parameter       DATA_WIDTH    = 8            , // 数据位宽, 可取1, 2, 3, ... , 默认为8
    parameter       ADDR_WIDTH    = 4            , // 地址位宽, 可取1, 2, 3, ... , 默认为4, 对应深度2**4
    parameter       RAM_STYLE     = "distributed", // RAM类型, 可选"block", "distributed"(默认)
    parameter       TH_WR         = 1'b1         , // the waterlevel of almost full
    parameter       TH_RD         = 1'b1         , // the waterlevel of almost empty
    parameter [0:0] FWFT_EN       = 1              // 首字直通特性使能, 默认为1, 表示使能首字直通, first-word fall-through
)(
    input                     wr_valid     ,
    input   [DATA_WIDTH-1:0]  wr_din       ,
    output                    wr_ready     ,

//    output                    full         ,
    
    output                    rd_valid     ,                   
    output  [DATA_WIDTH-1:0]  rd_dout      ,
    input                     rd_ready     ,

//    output                    empty        ,
    
    input                     clk          ,
    input                     rst_n
);


wire wr_en  ;
wire rd_en  ;
wire full   ;
wire empty  ;




wire [ADDR_WIDTH-1+1 : 0] rptr     ;
wire [ADDR_WIDTH-1+1 : 0] rptr_nxt ;
wire                      rptr_ld  ;
assign rptr_nxt = rptr + 1'b1      ;
assign rptr_ld  = rd_en & (~empty) ;
gnrl_dfflr #(ADDR_WIDTH + 1) gnrl_dfflr_rptr(rptr_ld,rptr_nxt,rptr,clk,rst_n);

wire [ADDR_WIDTH-1+1 : 0] wptr     ;
wire [ADDR_WIDTH-1+1 : 0] wptr_nxt ;
wire                      wptr_ld  ;
assign wptr_nxt = wptr + 1'b1      ;
assign wptr_ld  = wr_en & (~full)  ;
gnrl_dfflr #(ADDR_WIDTH + 1) gnrl_dfflr_wptr(wptr_ld,wptr_nxt,wptr,clk,rst_n);


wire [ADDR_WIDTH-1:0] raddr ;
wire [ADDR_WIDTH-1:0] waddr ;
assign raddr = rptr[ADDR_WIDTH-1:0];
assign waddr = wptr[ADDR_WIDTH-1:0];

assign empty = (rptr == wptr) ? 1'b1 : 1'b0 ; // when in reset state, both rptr and wptr are zero

assign full = ( (wptr[ADDR_WIDTH] != rptr[ADDR_WIDTH]) 
                && 
                (wptr[ADDR_WIDTH-1:0] == rptr[ADDR_WIDTH-1:0])
              ) ? 1'b1 : 1'b0;

localparam DEPTH = 1 << ADDR_WIDTH; 
(* ram_style = RAM_STYLE *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

always @(posedge clk) begin
    if (wr_en && ~full) begin 
        mem[waddr] <= wr_din;
    end
end

generate
    if( FWFT_EN == 1 ) begin
        //=========================== first-word fall-through mode begin ====================== 
        wire [DATA_WIDTH-1:0] dout_old       ;
        wire                  dout_old_ld    ;
        assign dout_old_ld = rd_en & (~empty);
        gnrl_dfflr #(DATA_WIDTH) gnrl_dfflr_old(dout_old_ld,mem[raddr],dout_old,clk,rst_n);

        assign rd_dout = (~empty) ? mem[raddr] : dout_old ;
        //=========================== first-word fall-through mode  end  ====================== 
    end else begin
        //=========================== normal mode begin ====================== 
        reg [DATA_WIDTH-1:0] dout_r;
        always @(posedge clk) begin
            if (rd_en && ~empty) begin 
                dout_r <= mem[raddr];
            end
        end

        assign rd_dout = dout_r;
        //=========================== normal mode  end  ====================== 
    end
endgenerate

endmodule