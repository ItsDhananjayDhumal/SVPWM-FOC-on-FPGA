`timescale 1ns / 1ps

module tb_deadband();

    // --- Signals ---
    reg clk_50M;
    reg rst_n;
    
    // Duty cycle inputs for each phase
    reg [11:0] duty_u;
    reg [11:0] duty_v;
    reg [11:0] duty_w;
    
    // Raw PWM outputs from the capwm modules
    wire pwm_u_raw;
    wire pwm_v_raw;
    wire pwm_w_raw;
    
    // Deadband outputs to the gate drivers (High and Low sides)
    wire pwm_u_h, pwm_u_l;
    wire pwm_v_h, pwm_v_l;
    wire pwm_w_h, pwm_w_l;

    // --- Clock Generation ---
    // 50MHz clock = 20ns period (toggle every 10ns)
    initial clk_50M = 0;
    always #10 clk_50M = ~clk_50M;

    // --- Module Instantiations ---

    // Phase U
    capwm phase_u_pwm (
        .clk(clk_50M), .rst_n(rst_n), .duty_cycle(duty_u), .pwm_out(pwm_u_raw)
    );
    phase_pwm db_u (
        .clk(clk_50M), .rst_n(rst_n), .pwm_in(pwm_u_raw), .pwm(pwm_u_h), .com_pwm(pwm_u_l)
    );

    // Phase V
    capwm phase_v_pwm (
        .clk(clk_50M), .rst_n(rst_n), .duty_cycle(duty_v), .pwm_out(pwm_v_raw)
    );
    phase_pwm db_v (
        .clk(clk_50M), .rst_n(rst_n), .pwm_in(pwm_v_raw), .pwm(pwm_v_h), .com_pwm(pwm_v_l)
    );

    // Phase W
    capwm phase_w_pwm (
        .clk(clk_50M), .rst_n(rst_n), .duty_cycle(duty_w), .pwm_out(pwm_w_raw)
    );
    phase_pwm db_w(
        .clk(clk_50M), .rst_n(rst_n), .pwm_in(pwm_w_raw), .pwm(pwm_w_h), .com_pwm(pwm_w_l)
    );

    // --- Stimulus & Test Sequence ---
    initial begin
        // 1. Initialize variables
        rst_n  = 0;
        duty_u = 12'd0;
        duty_v = 12'd0;
        duty_w = 12'd0;
        
        // Wait 100ns, then release reset
        #100;
        rst_n = 1;
        
        // 2. Apply different duty cycles to observe center alignment
        // Max value is 4095. 
        duty_u = 12'd2048; // ~50% duty cycle
        duty_v = 12'd1024; // ~25% duty cycle
        duty_w = 12'd3072; // ~75% duty cycle
        
        // 3. Wait for a few PWM periods
        // At 50MHz and 4096 max count, the PWM frequency is ~6.1kHz
        // One PWM period is roughly 164us (164,000 ns).
        // Wait for 3 periods to see stable waveforms.
        #(164000 * 3);
        
        // 4. Test an edge case: 0% and 100% duty cycles
        duty_u = 12'd0;    // 0%
        duty_v = 12'd4095; // 100%
        
        #(164000 * 2);

        // 5. End Simulation
        $display("Simulation Complete.");
        $finish;
    end

endmodule