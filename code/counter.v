module counter ( 
  input   wire  [4:0]     In,
  input   wire            Load, Up, Down,
  input   wire            Clk,
  input   wire            Rst,
  output  reg   [4:0]     Counter,
  output  wire            High, Low
  );
  

  reg [4:0]   Counter_comb ;


  always @ (posedge Clk or negedge Rst)
    begin
      if(!Rst)
        begin
          Counter <= 5'b0;
        end
      else begin
        Counter <= Counter_comb ;  
      end
    end
 
  always @ (*)
   begin
     if (Load)begin
         Counter_comb = In ;
       end
     else if (Down && !Low && !Up)begin
         Counter_comb = Counter - 5'b1;
       end
     else if (Up && !High && !Down)begin
         Counter_comb = Counter + 5'b1;
       end
     else begin
         Counter_comb = Counter ;
       end
   end

  assign Low = (Counter == 5'b0);

  assign High = (Counter == 5'b11111);
  
  initial begin
    Counter =5'b0;
  end
endmodule
