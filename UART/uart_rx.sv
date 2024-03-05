module uart_rx(

    input Rs232_Rx,
    input [2:0] Baud_Set,
    input Clk,
    input Rst_n,

    output reg [7:0]Data_Byte,
    output reg Rx_Done
);

    reg r1_Rs232_Rx,r2_Rs232_Rx;
    reg s1_Rs232_Rx,s2_Rs232_Rx;
    wire neg;
    reg [15:0] bps_DR;
    reg [15:0] div_cnt;
    reg div_pulse;
    reg [7:0]pulse_cnt;
    reg [2:0] START_BIT,STOP_BIT;
    reg [2:0] r_data_byte[7:0];
    reg RX_en;


    assign neg = !s1_Rs232_Rx && s2_Rs232_Rx;
    //asynchronise to synchronise
    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            begin
                r1_Rs232_Rx <= 1'b0;
                r2_Rs232_Rx <= 1'b0;
            end
        else 
            begin
                r1_Rs232_Rx <= Rs232_Rx;
                r2_Rs232_Rx <= r1_Rs232_Rx;
            end

    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            begin
                s1_Rs232_Rx <= 1'b0;
                s2_Rs232_Rx <= 1'b0;
            end
        else 
            begin
                s1_Rs232_Rx <= r2_Rs232_Rx;
                s2_Rs232_Rx <= s1_Rs232_Rx;
            end
    
    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            bps_DR <= 16'd0;
        else 
            case(Baud_Set)
                0:bps_DR <= 16'd324;
                1:bps_DR <= 16'd162;
                2:bps_DR <= 16'd80;
                3:bps_DR <= 16'd53;
                4:bps_DR <= 16'd26;
            endcase
    
    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            div_cnt <= 16'd0;
        else if(div_cnt == bps_DR)
            div_cnt <= 16'd0;
        else 
            div_cnt <= div_cnt + 1'b1;
    
    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            div_pulse <= 1'd0;
        else if(div_cnt == 16'd1)
            div_pulse <= 1'd1;
        else 
            div_pulse <= 1'b0;   
    
    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            pulse_cnt <= 8'd0;
        else if(pulse_cnt == 16'd159 || (pulse_cnt ==8'd12 && (START_BIT >2)))
            pulse_cnt <= 8'd0;
        else if(div_pulse)
            pulse_cnt <= pulse_cnt + 1'b1; 
        else 
            pulse_cnt <= pulse_cnt ;

    always@(posedge Clk or negedge Rst_n )
        if(!Rst_n)
            Rx_Done <=1'b0;
        else if(pulse_cnt == 8'd159)
            Rx_Done <=1'b1;
        else 
            Rx_Done <=1'b0;

    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            begin
                START_BIT <= 3'd0;
                r_data_byte[0] <= 3'd0;
                r_data_byte[1] <= 3'd0;
                r_data_byte[2] <= 3'd0;
                r_data_byte[3] <= 3'd0;
                r_data_byte[4] <= 3'd0;
                r_data_byte[5] <= 3'd0;
                r_data_byte[6] <= 3'd0;
                r_data_byte[7] <= 3'd0;
                STOP_BIT <= 3'd0;
            end
        else if(div_pulse)
            begin
            case(pulse_cnt )
                0:
                    begin
                        START_BIT <= 3'd0;
                        r_data_byte[0] <= 3'd0;
                        r_data_byte[1] <= 3'd0;
                        r_data_byte[2] <= 3'd0;
                        r_data_byte[3] <= 3'd0;
                        r_data_byte[4] <= 3'd0;
                        r_data_byte[5] <= 3'd0;
                        r_data_byte[6] <= 3'd0;
                        r_data_byte[7] <= 3'd0;
                        STOP_BIT <= 3'd0;
                    end
                6,7,8,9,10,11:  START_BIT <= START_BIT + r2_Rs232_Rx;
                22,23,24,25,26,27: r_data_byte[0] <= r_data_byte[0] + r2_Rs232_Rx;
                38,39,40,41,42,43:r_data_byte[1] <= r_data_byte[1] + r2_Rs232_Rx;
                54,55,56,57,58,59:r_data_byte[2] <= r_data_byte[2] + r2_Rs232_Rx;
                70,71,72,73,74,75:r_data_byte[3] <= r_data_byte[3] + r2_Rs232_Rx;
                86,87,88,89,90,91:r_data_byte[4] <= r_data_byte[4] + r2_Rs232_Rx;
                102,103,104,105,106,107:r_data_byte[5] <= r_data_byte[5] + r2_Rs232_Rx;
                118,119,120,121,122,123:r_data_byte[6] <= r_data_byte[6] + r2_Rs232_Rx;
                134,135,136,137,138,139:r_data_byte[7] <= r_data_byte[7] + r2_Rs232_Rx;
                150,151,152,153,154,155:STOP_BIT <= STOP_BIT + r2_Rs232_Rx; 
                default: 
                    begin
                        START_BIT <= START_BIT;
                        r_data_byte[0] <=  r_data_byte[0];
                        r_data_byte[1] <=  r_data_byte[1];
                        r_data_byte[2] <=  r_data_byte[2];
                        r_data_byte[3] <=  r_data_byte[3];
                        r_data_byte[4] <=  r_data_byte[4];
                        r_data_byte[5] <=  r_data_byte[5];
                        r_data_byte[6] <=  r_data_byte[6];
                        r_data_byte[7] <=  r_data_byte[7];
                        STOP_BIT <= STOP_BIT;                       
                    end               
            endcase
            end

        always@(posedge Clk or negedge Rst_n)
            if(!Rst_n)
                Data_Byte <= 8'd0;
            else if(pulse_cnt == 8'd159)
                begin
                   Data_Byte[0] <=  r_data_byte[0][2];
                   Data_Byte[1] <=  r_data_byte[1][2];
                   Data_Byte[2] <=  r_data_byte[2][2]; 
                   Data_Byte[3] <=  r_data_byte[3][2];
                   Data_Byte[4] <=  r_data_byte[4][2];
                   Data_Byte[5] <=  r_data_byte[5][2];
                   Data_Byte[6] <=  r_data_byte[6][2]; 
                   Data_Byte[7] <=  r_data_byte[7][2];              
                end
endmodule 