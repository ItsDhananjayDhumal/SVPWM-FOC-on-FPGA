`timescale 1ns / 1ps

module phase_vector_generator(
    input clk_50M,
    input wire [11:0] elec_angle,
    input wire [9:0] modulation,
    output reg [11:0] duty_a, duty_b, duty_c
    );
    
wire [11:0] sine, sine_60;
wire [14:0] six_times_angle;
wire [2:0] sector;
wire [11:0] alpha, sixty_minus_alpha;

wire [11:0] T1, T2, dead_time;

wire [21:0] temp_T1, temp_T2;

assign six_times_angle = 6 * elec_angle;
assign sector = six_times_angle[14:12];

assign alpha = six_times_angle[11:0];
assign sixty_minus_alpha = 12'd4095 - alpha;

sine_lut lut1 (.angle(alpha),
               .sine_value(sine));
sine_lut lut2 (.angle(sixty_minus_alpha),
               .sine_value(sine_60));
                
assign temp_T1 = modulation * sine;
assign temp_T2 = modulation * sine_60;

assign T1 = temp_T1 >> 10;
assign T2 = temp_T2 >> 10;

assign dead_time = (12'd4095 - T1 - T2) >> 1;

// sector 0: between a c'
// sector 1: between c' b
// sector 2: netween b a'
// sector 3: between a' c
// sector 4: between c b'
// sector 5: netween b' a

always @(posedge clk_50M) begin
    case(sector)    
        3'd0: begin
            duty_a <= T1 + T2 + dead_time;
            duty_b <= T1 + dead_time;
            duty_c <= dead_time;
        end
        3'd1: begin
            duty_b <= T1 + T2 + dead_time;
            duty_a <= T2 + dead_time;
            duty_c <= dead_time;
        end    
        3'd2: begin
            duty_b <= T1 + T2 + dead_time;
            duty_c <= T1 + dead_time;
            duty_a <= dead_time;
        end      
        3'd3: begin
            duty_c <= T1 + T2 + dead_time;
            duty_b <= T2 + dead_time;
            duty_a <= dead_time;
        end
        3'd4: begin
            duty_c <= T1 + T2 + dead_time;
            duty_a <= T1 + dead_time;
            duty_b <= dead_time;
        end    
        3'd5: begin
            duty_a <= T1 + T2 + dead_time;
            duty_c <= T2 + dead_time;
            duty_b <= dead_time;
        end 
        default: begin
            duty_a <= 0;
            duty_b <= 0;
            duty_c <= 0;
        end                
    endcase    
end
                
endmodule

