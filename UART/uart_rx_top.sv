module uart_rx_top(
	input Clk,
	input Rst_n,
	input Rs232_Rx

);

	wire Rx_Done;
	wire [7:0] Data_Byte;
	reg  [7:0] r_Data_Byte;

uart_rx uart_rx_0(

     .Rs232_Rx(Rs232_Rx),
     .Baud_Set(3'd0),
     .Clk(Clk),
     .Rst_n(Rst_n),
     .Data_Byte(Data_Byte),
     .Rx_Done(Rx_Done)
);


ISSP_rx ISSP_rx_0(
		    .probe(r_Data_Byte)  // probes.probe
	);
	
	always@(posedge Clk or negedge Rst_n)
		if(!Rst_n)
			r_Data_Byte <= 8'd0;
		else if(Rx_Done)
			r_Data_Byte <= Data_Byte;
		else 
			r_Data_Byte <= r_Data_Byte;
			
			

endmodule 