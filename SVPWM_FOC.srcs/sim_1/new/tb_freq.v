`timescale 1ns / 1ps

module tb_freq();

    reg clk_50M;
    reg rst_n;
    reg [11:0] elec_angle;
    reg [9:0] modulation;
    wire phase_a;
    wire phase_b;
    wire phase_c;

    // Instantiate the Top Module
    SVPWM uut (
        .clk_50M(clk_50M),
        .rst_n(rst_n),
        .elec_angle(elec_angle),
        .modulation(modulation),
        .phase_a(phase_a),
        .phase_b(phase_b),
        .phase_c(phase_c)
    );

    // 50 MHz Clock Generation (20ns period)
    initial clk_50M = 0;
    always #10 clk_50M = ~clk_50M;

    // Integer for the sweep loop
    integer i;

    initial begin
        // Initialize Inputs
        rst_n = 0;
        elec_angle = 0;
        modulation = 10'd1000; // High modulation to see the saddle clearly

        // Wait 100 ns for global reset
        #100;
        rst_n = 1;
        #100;

        // Sweep the angle from 0 to 4095
        // We wait 50 microseconds per step to let the PWM cycle run a few times
//        for (i = 0; i < 4096; i = i + 1) begin
//            elec_angle = i[11:0];
//            #50000; 
//        end
//        for (; i < 8192; i = i + 1) begin
//            elec_angle = i[11:0];
//            #25000; 
//        end
//        for (; i < 12288; i = i + 1) begin
//            elec_angle = i[11:0];
//            #12500; 
//        end
//        for (; i < 24576; i = i + 1) begin
//            elec_angle = i[11:0];
//            #6250; 
//        end

        for (i = 0; i < 4096; i = i + 1) begin
            elec_angle = i[11:0];
            #3125; 
        end
        for (; i < 8192; i = i + 1) begin
            elec_angle = i[11:0];
            #3125; 
        end
        for (; i < 12288; i = i + 1) begin
            elec_angle = i[11:0];
            #3125; 
        end
        for (; i < 24576; i = i + 1) begin
            elec_angle = i[11:0];
            #3125; 
        end
                
        $display("Simulation Complete.");
        $finish;
    end

endmodule