`timescale 1ns/10ps
module i2c_bit_shift(
	Clk,
	Rst_n,
	
	Cmd,
	Go,
	Rx_DATA,
	Tx_DATA,
	Trans_Done,
	ack_o,
	i2c_sclk,
	i2c_sdat
);
	
	input Clk;
	input Rst_n;
	
	input [5:0]Cmd; //来自控制模块的指令
	input Go;
	output reg[7:0]Rx_DATA; //读的数据
	input [7:0]Tx_DATA;
	output reg Trans_Done; //发送完成信号
	output reg ack_o;
	output reg i2c_sclk;  //i2c时钟
	inout i2c_sdat;    //发送的数据

    reg i2c_sdat_o;

    //系统时钟采用50MHz
	parameter SYS_CLOCK = 50_000_000;
	//SCL总线时钟采用400kHz
	parameter SCL_CLOCK = 400_000;
	//产生时钟SCL计数器最大值---这里将SCL的时钟再进行一个四分频
	localparam SCL_CNT_M = SYS_CLOCK/SCL_CLOCK/4 - 1;

    reg i2c_sdat_oe; //主要控制是输入还是输出

    localparam 
		WR =  6'b000001,	// 写请求
		STA = 6'b000010,	//起始位请求
		RD =  6'b000100,	//读请求
		STO = 6'b001000,	//停止位请求
		ACK = 6'b010000,	//应答位请求
		NACK = 6'b100000;	//无应答请求

    reg[19:0] div_cnt;
    reg en_div_cnt;//计数使能
    always @(posedge Clk or negedge Rst_n) begin
        if(!Rst_n)
            div_cnt <= 20'd0;
        else if(en_div_cnt)begin
            if(div_cnt < SCL_CNT_M)
                div_cnt <= div_cnt + 1'b1;
            else 
                div_cnt <= 20'd0;
        end
    end

    wire sclk_plus = div_cnt == SCL_CNT_M; //分频时钟产生的脉冲

    //总线没有能力输出高电平，因此如果输出1‘bz那么这个意思代表了通过外部的上拉电阻输出为1
    assign i2c_sdat =i2c_sdat_oe?(i2c_sdat_o?1'bz:1'b0):1'bz;
    
    reg [7:0]state;
    //利用one-hot编码设计的状态这样有助于，利用位与操作判断
	localparam
		IDLE = 		8'b00000001,
		GEN_STA = 	8'b00000010,
		WR_DATA = 	8'b00000100,
		RD_DATA = 	8'b00001000,
		CHECK_ACK = 8'b00010000,
		GEN_ACK = 	8'b00100000,
		GEN_STO = 	8'b01000000;

    reg [4:0]cnt;

    always@(posedge Clk or negedge Rst_n) 
        if(!Rst_n)
            begin
                Rx_DATA <= 8'd0;
                i2c_sdat_oe <= 1'b0;
                en_div_cnt <= 1'b0;
                i2c_sdat_o <= 1'd1;
                Trans_Done <= 1'b0;
                ack_o <= 1'b0;
                state <= IDLE;
                cnt <= 0;
            end
        else 
            begin
                case(state)
                IDLE:
                    begin
                        Trans_Done <= 1'b0;
                        i2c_sdat_oe <= 1'b1;
                        if(Go)
                            begin
                               en_div_cnt <= 1'b1;//计数器启动
                                if(Cmd & STA)
                                    state <= GEN_STA;
                                else if(Cmd & RD)
                                    state <= RD_DATA;
                                else if(Cmd & WR)
                                    state <= WR_DATA;
                                else 
                                    state <= IDLE;
                            end
                        else 
                            begin
                               en_div_cnt <= 1'b0;
                               state <= IDLE; 
                            end
                    end
                //产生一个start信号
                //数据为输出的时候同时时钟从高电平变成低电平    
                GEN_STA:
                    begin
                        if(sclk_plus)
                            begin
                                if(cnt == 5'd3)
                                    cnt <= 5'd0;
                                else 
                                    cnt <= cnt + 1'b1;
                                case(cnt)
                                    5'd0:begin i2c_sdat_o <= 1'b1;i2c_sdat_oe <= 1'b1; end
                                    5'd1:begin i2c_sclk <= 1'b1; end
                                    5'd2:begin i2c_sdat_o <= 1'b0; end
                                    5'd3:begin i2c_sclk <= 1'b0; end
                                    default:begin i2c_sdat_o <= 1; i2c_sclk <= 1; i2c_sclk <= 1'b1;end
                                endcase
                                //STA后面肯定跟着写操作因为这时候要写地址和读写信号位
                                if(cnt ==3 )
                                    begin
                                        if(Cmd & WR)
                                            state <= WR_DATA;
                                    end
                            end
                    end
                //将TX_DATA信号发送出去
                WR_DATA:
                    begin
                        if(sclk_plus)begin
                            if(cnt == 5'd31)
                                cnt <= 5'd0;
                            else 
                                cnt <= cnt + 1'b1;
                            case(cnt)
                                //这里设置为输出同时因为每四个周期变化一次所以可以根据第四位和第二位的取值
                                0,4,8,12,16,20,24,28: begin i2c_sdat_oe <= 1'd1; i2c_sdat_o <= Tx_DATA[7-cnt[4:2]];i2c_sclk <= 1'b0; end //set data
                                1,5,9,13,17,21,25,29: begin i2c_sclk <= 1'b1; end
                                2,6,10,14,18,22,26,30:begin i2c_sclk <= 1'b1; end
                                3,7,11,15,19,23,27,31:begin i2c_sclk <= 1'b0; end
                                default:begin i2c_sdat_o <= 1; i2c_sclk <= 1;end
                            endcase
                            if(cnt == 5'd31)
                                state <= CHECK_ACK;
                        end
                    end
                //读数据
                RD_DATA:
                    begin
                        if(sclk_plus)begin
                            if(cnt == 31)
                               cnt <= 0;
                            else 
                                cnt <= cnt + 1'b1;
                            case(cnt)
                                //修改为输入模式，时钟开始为敌当时钟稳定之后采集数据
                                0,4,8,12,16,20,24,28:begin i2c_sdat_oe <= 1'd0; i2c_sclk <= 0; end
                                1,5,9,13,17,21,25,29:begin i2c_sclk <= 1;end
                                2,6,10,14,18,22,26,30:begin i2c_sclk <= 1; Rx_DATA <= {Rx_DATA[6:0],i2c_sdat}; end
                                3,7,11,15,19,23,27,31:begin i2c_sclk <= 0; end
                                default:begin i2c_sdat_o <= 1; i2c_sclk <= 1;end
                            endcase 
		        			if(cnt == 5'd31)begin
		        				state <= GEN_ACK;
		        			end
                        end
                    end
                //确认响应
                CHECK_ACK:
                    begin
                        if(sclk_plus)
                            begin
                                if(cnt == 3)
                                   cnt <= 0;
                                else 
                                   cnt <= cnt + 1'b1;
                                case(cnt)
                                    5'd0:begin i2c_sdat_oe <= 1'd0; i2c_sclk <= 0;  end
                                    5'd1:begin i2c_sclk <= 1; end
                                    5'd2:begin i2c_sclk <= 1; ack_o <= i2c_sdat; end
                                    5'd3:begin i2c_sclk <= 0; end
                                    default:begin i2c_sdat_o <= 1; i2c_sclk <= 1;end
                                endcase 
                                //确认响应之后可能是STO结束了，也可能是要进行其他读或者写操作所以回到IDLE
                                if(cnt == 3)begin
                                    if(Cmd & STO)
                                       state <= GEN_STO;
                                    else begin
		        						state <= IDLE;
		        						Trans_Done <= 1'b1;                                
                                    end     
                                end
                            end
                    end
                    
                //产生应答和非应答信号
			    GEN_ACK:
			    	begin
			    		if(sclk_plus)begin
			    			if(cnt == 3)
			    				cnt <= 0;
			    			else
			    				cnt <= cnt + 1'b1;
			    			case(cnt)
			    				0:begin 
			    						i2c_sdat_oe <= 1'd1;
			    						i2c_sclk <= 0;
			    						if(Cmd & ACK)
			    							i2c_sdat_o <= 1'b0;
			    						else if(Cmd & NACK)
			    							i2c_sdat_o <= 1'b1;
			    					end
			    				1:begin i2c_sclk <= 1;end
			    				2:begin i2c_sclk <= 1;end
			    				3:begin i2c_sclk <= 0;end
			    				default:begin i2c_sdat_o <= 1; i2c_sclk <= 1;end
			    			endcase
			    			if(cnt == 3)begin
			    				if(Cmd & STO)
			    					state <= GEN_STO;
			    				else begin
			    					state <= IDLE;
			    					Trans_Done <= 1'b1;
			    				end
			    			end
			    		end
			    	end
			    GEN_STO:
			    	begin
			    		if(sclk_plus)begin
			    			if(cnt == 3)
			    				cnt <= 0;
			    			else
			    				cnt <= cnt + 1'b1;
			    			case(cnt)
			    				0:begin i2c_sdat_o <= 0; i2c_sdat_oe <= 1'd1;end
			    				1:begin i2c_sclk <= 1;end
			    				2:begin i2c_sdat_o <= 1; i2c_sclk <= 1;end
			    				3:begin i2c_sclk <= 1;end
			    				default:begin i2c_sdat_o <= 1; i2c_sclk <= 1;end
			    			endcase
			    			if(cnt == 3)begin
			    				Trans_Done <= 1'b1;
			    				state <= IDLE;
			    			end
			    		end
			    	end
                    default:state <= IDLE;
                endcase
            end
  


endmodule 