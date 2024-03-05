module uart_tx(

    input Clk,
    input Rst_n,
    input Send_en,
    input [7:0]data_byte,
    input [2:0]baud_Set,

    output reg Rs232_Tx,
    output reg Tx_Done,
    output reg uart_state 

);

    reg [15:0]bps_DR;
    reg [15:0]div_cnt;
    reg div_pulse;
    reg [3:0]bps_cnt;
    reg [7:0]r_data_type;

    localparam START_BIT = 1'b0;
    localparam STOP_BIT  = 1'b1;

    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            bps_DR <= 16'd5208;
        else 
            case(baud_Set)
                0: bps_DR <= 16'd5207; //9600bps
                1: bps_DR <= 16'd2603; //19200bps
                2: bps_DR <= 16'd1301; //38400bps
                3: bps_DR <= 16'd867;  //57600bps
                4: bps_DR <= 16'd433;  //115200bps
                default: bps_DR <= 16'd5208;
            endcase

    always@(posedge Clk or negedge Rst_n )
        if(!Rst_n)
            div_cnt <= 16'd0;
        else if(uart_state)
            begin
                if(div_cnt == bps_DR)
                    div_cnt <= 16'd0;
                else 
                    div_cnt <= div_cnt +1'b1;
            end
        else 
            div_cnt <= 16'd0;

    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            div_pulse <= 1'b0;
        else if(div_cnt == 16'd1)
            div_pulse <= 1'b1;
        else 
            div_pulse <= 1'b0;
    
    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            bps_cnt <= 4'd0;
        else if(bps_cnt == 4'd11)
            bps_cnt <= 4'd0;
        else if(div_pulse)
            bps_cnt <= bps_cnt + 1'b1;


     always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            Tx_Done <= 1'b0;
        else if(bps_cnt == 4'd11)
            Tx_Done <= 1'b1;
        else
            Tx_Done <= 1'b0;

    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            uart_state <= 1'b0;
        else if(Send_en)
            uart_state <= 1'b1;
        else if(bps_cnt == 4'd11)
            uart_state <= 1'b0;
        else 
            uart_state <= uart_state;

    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            r_data_type <= 8'b0;
        else if(Send_en)
            r_data_type <= data_byte;
        else 
            r_data_type <= r_data_type;

    always@(posedge Clk or negedge Rst_n)
        if(!Rst_n)
            Rs232_Tx <= 1'b1;
        else 
            case(bps_cnt)
                0: Rs232_Tx <= 1'b1;
                1: Rs232_Tx <= START_BIT;
                2: Rs232_Tx <= r_data_type[0];
                3: Rs232_Tx <= r_data_type[1];
                4: Rs232_Tx <= r_data_type[2];
                5: Rs232_Tx <= r_data_type[3];
                6: Rs232_Tx <= r_data_type[4];
                7: Rs232_Tx <= r_data_type[5];
                8: Rs232_Tx <= r_data_type[6];
                9: Rs232_Tx <= r_data_type[7];
                10: Rs232_Tx <= STOP_BIT;
            default:Rs232_Tx <= 1'b1;
            endcase

endmodule 