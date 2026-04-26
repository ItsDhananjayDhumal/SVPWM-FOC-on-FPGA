`timescale 1ns / 1ps

module SVPWM(
    input clk_50M,
    input rst_n,
    input wire [11:0] elec_angle,
    input wire [9:0] modulation,
    output phase_a_plus, phase_b_plus, phase_c_plus, phase_a_minus, phase_b_minus, phase_c_minus 
    );
    
wire [11:0] duty_a, duty_b, duty_c; 
wire phase_a, phase_b, phase_c;   
    
phase_vector_generator inst_pvg (.clk_50M(clk_50M),
                                 .modulation(modulation),
                                 .elec_angle(elec_angle),
                                 .duty_a(duty_a),
                                 .duty_b(duty_b),
                                 .duty_c(duty_c));   
                                 
capwm phasea (.clk(clk_50M),
              .rst_n(rst_n),
              .duty_cycle(duty_a),
              .pwm_out(phase_a));

capwm phaseb (.clk(clk_50M),
              .rst_n(rst_n),
              .duty_cycle(duty_b),
              .pwm_out(phase_b));
    
capwm phasec (.clk(clk_50M),
              .rst_n(rst_n),
              .duty_cycle(duty_c),
              .pwm_out(phase_c));
              
phase_pwm phaseA (.clk(clk_50M),
                  .rst_n(rst_n),
                  .pwm_in(phase_a),
                  .pwm(phase_a_plus),
                  .com_pwm(phase_a_minus));            
              
phase_pwm phaseB (.clk(clk_50M),
                  .rst_n(rst_n),
                  .pwm_in(phase_b),
                  .pwm(phase_b_plus),
                  .com_pwm(phase_b_minus));
                  
phase_pwm phaseC (.clk(clk_50M),
                  .rst_n(rst_n),
                  .pwm_in(phase_c),
                  .pwm(phase_c_plus),
                  .com_pwm(phase_c_minus));
                      
endmodule
