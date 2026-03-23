`timescale 1ns / 1ps


module pwm_test(
    input clk_50M,
    output pwm, com_pwm
    );
    
    capwm gen (.clk(clk_50M),
               .duty_cycle(12'b011111111111),
               .rst_n(1'b1),
               .pwm_out(pwm));
               
    complimentary_capwm gen1 (.clk_50M(clk_50M),
                              .pwm(pwm),
                              .complimentary_pwm(com_pwm));
    
endmodule
