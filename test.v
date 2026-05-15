module test;

reg sys_clk, sys_rst;
wire baud_clk;

u_baud uut(.sys_clk(sys_clk), .sys_rst(sys_rst), .baud_clk(baud_clk));

initial sys_clk = 0;

always #10 sys_clk = ~sys_clk;

initial begin
    sys_rst = 1;
    #100 sys_rst = 0;
    #100000;
    $finish;
end

initial begin
    $monitor("Time = %t, baud_clk = %b", $time, baud_clk);
end

endmodule
