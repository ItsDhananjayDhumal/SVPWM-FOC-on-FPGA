`timescale 1ns / 1ps

module tb_capwm;

    // Inputs
    reg clk;
    reg rst_n;
    reg [11:0] duty_cycle;

    // Outputs
    wire pwm_out;

    // Instantiate the Unit Under Test (UUT)
    capwm uut (
        .clk(clk),
        .rst_n(rst_n),
        .duty_cycle(duty_cycle),
        .pwm_out(pwm_out)
    );

    // Clock generation: 50 MHz -> 20 ns period (10 ns high, 10 ns low)
    always #10 clk = ~clk;

    // Task to wait for N full PWM periods
    // A 10 kHz PWM period is exactly 100 us (or 5000 clock cycles at 50 MHz)
    task wait_pwm_periods(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                // Wait until the counter hits the bottom of the triangle wave (0)
                @(posedge clk);
                while (uut.counter != 12'd0) begin
                    @(posedge clk);
                end
                // Step one clock cycle past 0 to avoid double-counting the same period
                @(posedge clk);
            end
        end
    endtask

    integer percent;

    initial begin
        // Initialize Inputs
        clk = 0;
        rst_n = 0;
        duty_cycle = 0;

        // Wait 100 ns for global reset
        #100;
        rst_n = 1;

        $display("--- Starting 10 kHz Center-Aligned PWM Simulation ---");

        // Loop from 10% to 100% in increments of 10%
        for (percent = 10; percent <= 100; percent = percent + 10) begin
            // Calculate the exact 12-bit register value (Max count is 2500)
            duty_cycle = (percent * 12'd2500) / 100;
            
            $display("Time: %0t ns | Target: %0d%% | Register Value: %0d", $time, percent, duty_cycle);

            // Hold this specific duty cycle for 10 full PWM periods
            wait_pwm_periods(10);
        end

        $display("Time: %0t ns | Simulation Complete.", $time);
        $finish;
    end

    // Waveform dumping for GTKWave or Vivado
//    initial begin
//        $dumpfile("pwm_50mhz_10khz.vcd");
//        $dumpvars(0, tb_center_aligned_pwm);
//    end

endmodule