`timescale 1ns / 1ps

module phase_pwm (
    input  wire clk,
    input  wire rst_n,
    input  wire pwm_in,
    output reg  pwm,
    output reg  com_pwm
);

    parameter DEADBAND = 1; // micorsec   
     
    reg pwm_in_prev;
    reg [11:0] counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_in_prev <= 1'b0;
            counter <= 0;
            pwm <= 1'b0;
            com_pwm <= 1'b0;
        end 
        else begin
            pwm_in_prev <= pwm_in;
            if (pwm_in != pwm_in_prev) begin
                counter <= 0;
                pwm   <= 1'b0;
                com_pwm   <= 1'b0;
            end else begin
                if (counter < DEADBAND * 50) begin
                    counter <= counter + 1'b1;
                    pwm   <= 1'b0;
                    com_pwm   <= 1'b0;
                end 
                else begin
                    pwm   <= pwm_in;
                    com_pwm   <= ~pwm_in;
                end
            end
        end
    end

endmodule