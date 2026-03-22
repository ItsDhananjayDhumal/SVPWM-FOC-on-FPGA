`timescale 1ns / 1ps

module tb_modulation();

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
    integer angle_idx;

    initial begin
        // Initialize Inputs
        rst_n = 0;
        elec_angle = 0;
        modulation = 0;

        // Reset sequence
        #100;
        rst_n = 1;
        #100;

        // =================================================================
        // Sweep 1: High Modulation (Deep Saddle)
        // =================================================================
        modulation = 10'd1000;
        $display("Running Rotation 1: Modulation = 1000");
        for (angle_idx = 0; angle_idx < 8192; angle_idx = angle_idx + 8) begin
            elec_angle = angle_idx[11:0];
            #100000; // Wait 100 us to let the 10kHz PWM cycle complete
        end

        // =================================================================
        // Sweep 2: Medium-High Modulation
        // =================================================================
        modulation = 10'd700;
        $display("Running Rotation 2: Modulation = 700");
        for (angle_idx = 0; angle_idx < 8192; angle_idx = angle_idx + 8) begin
            elec_angle = angle_idx[11:0];
            #100000; 
        end

        // =================================================================
        // Sweep 3: Medium-Low Modulation
        // =================================================================
        modulation = 10'd400;
        $display("Running Rotation 3: Modulation = 400");
        for (angle_idx = 0; angle_idx < 8192; angle_idx = angle_idx + 8) begin
            elec_angle = angle_idx[11:0];
            #100000; 
        end

        // =================================================================
        // Sweep 4: Very Low Modulation (Nearly flat)
        // =================================================================
        modulation = 10'd100;
        $display("Running Rotation 4: Modulation = 100");
        for (angle_idx = 0; angle_idx < 8192; angle_idx = angle_idx + 8) begin
            elec_angle = angle_idx[11:0];
            #100000; 
        end

        $display("Simulation Complete.");
        $finish;
    end

endmodule

//// =================================================================
//// Behavioral Sine LUT (For Simulation Only)
//// Calculates sin(x) from 0 to 60 degrees. 
//// =================================================================
//module sine_lut(
//    input  wire [11:0] angle,
//    output wire [11:0] sine_value
//);
//    real radians;
//    real sin_real;
    
//    always @(angle) begin
//        // Convert 0-4095 to 0 -> Pi/3 radians (60 degrees)
//        radians = ($itor(angle) / 4096.0) * (3.1415926535 / 3.0);
        
//        // Calculate Sine and scale to 0-4095
//        sin_real = $sin(radians) * 4095.0;
//    end
    
//    assign sine_value = $rtoi(sin_real);
    
//endmodule