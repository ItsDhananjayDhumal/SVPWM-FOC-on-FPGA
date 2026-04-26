`timescale 1ns / 1ps

module us_md (
    input  wire CLOCK_50,
    input  wire [1:0] KEY, // KEY[0] used as Active-Low Reset (rst_n)
    
    // Encoder Pins
    input  wire enc_a,
    input  wire enc_b,
    input  wire enc_z,     // Left in port list for physical wiring, but ignored in logic
    
    // Inverter PWM outputs
    output wire phase_a_plus,
    output wire phase_a_minus,
    output wire phase_b_plus,
    output wire phase_b_minus,
    output wire phase_c_plus,
    output wire phase_c_minus,
    
    // Status LEDs
    output wire [7:0] LED
);

    // ==========================================
    // 1. Core Parameters
    // ==========================================
    // 2500 physical lines * 4 edges (4X decoding) = 10000 counts per revolution
    parameter PPR = 10000;            
    parameter POLE_PAIRS = 7;        // Matches your 14-pole drone motor
    parameter CLOCK_FREQ = 50_000_000;
    
    parameter ALIGN_MODULATION  = 10'd80;  // High enough to punch through 2us deadband safely

    // ==========================================
    // 2. PI Controller Parameters
    // ==========================================
    // Speed measurement timebase: 1 millisecond (50,000 clock cycles at 50MHz)
    parameter DT_CYCLES = 50_000; 
    
    // Target Speed: 100 ticks/ms = 600 RPM (with 10000 PPR)
    parameter TARGET_SPEED_TICKS = 16'd20; 
    
    // Damped PI Gains for clean, filtered signal and low-inertia drone motor
    parameter KP_GAIN = 32'd15;
    parameter KI_GAIN = 32'd2;
    parameter GAIN_SHIFT = 4'd8; 

    // FSM States
    localparam STATE_ALIGN = 2'd0;
    localparam STATE_WAIT  = 2'd1;
    localparam STATE_RUN   = 2'd2;

    // ==========================================
    // 3. Bulletproof 4X Encoder Logic
    // ==========================================
    reg [15:0] count = 0;
    
    // 2-stage synchronizers to filter out metastability from external pins
    reg [2:0] a_sync = 0;
    reg [2:0] b_sync = 0;
    
    always @(posedge CLOCK_50) begin
        a_sync <= {a_sync[1:0], enc_a};
        b_sync <= {b_sync[1:0], enc_b};
    end
    
    // Detect ANY edge (rising or falling) on either channel
    wire a_edge = a_sync[1] ^ a_sync[2];
    wire b_edge = b_sync[1] ^ b_sync[2];
    
    // 4X Direction calculation
    wire enc_dir = a_sync[1] ^ b_sync[2]; 

    always @(posedge CLOCK_50) begin
        if (!KEY[0]) begin
            count <= 0;
        end else if (a_edge || b_edge) begin 
            if (enc_dir) begin 
                if (count >= PPR - 1) count <= 0;
                else count <= count + 1;
            end else begin   
                if (count == 0) count <= PPR - 1;
                else count <= count - 1;
            end
        end
    end

    // ==========================================
    // 4. Electrical Angle Calculation (12-bit)
    // ==========================================
    wire [11:0] elec_angle_raw;
    wire [31:0] count_mult;
    
    assign count_mult = count * POLE_PAIRS * 32'd4096;
    assign elec_angle_raw = count_mult / PPR;

    // ==========================================
    // 5. Speed Measurement & Filtered PI Logic
    // ==========================================
    reg [31:0] dt_timer = 0;
    reg [15:0] prev_count = 0;
    reg signed [15:0] actual_speed = 0; // This now stores the FILTERED speed
    
    wire signed [16:0] count_diff = $signed({1'b0, count}) - $signed({1'b0, prev_count});
    
    reg signed [31:0] integral_error = 0;
    reg [9:0] pi_modulation_out = 0;
    
    always @(posedge CLOCK_50) begin
        if (!KEY[0] || state != STATE_RUN) begin
            dt_timer <= 0;
            prev_count <= count;
            actual_speed <= 0;
            integral_error <= 0;
            pi_modulation_out <= 0;
        end 
        else if (dt_timer >= DT_CYCLES) begin
            dt_timer <= 0;
            
            begin : PI_MATH
                reg signed [15:0] raw_speed;
                reg signed [15:0] filtered_speed;
                reg signed [31:0] error;
                reg signed [31:0] p_term;
                reg signed [31:0] next_integral;
                reg signed [31:0] raw_pi_out;

                // A. Calculate Raw Speed (Handle wrap around)
                if (count_diff > (PPR/2)) 
                    raw_speed = count_diff - PPR;
                else if (count_diff < -($signed(PPR)/2)) 
                    raw_speed = count_diff + PPR;
                else 
                    raw_speed = count_diff;
                    
                prev_count <= count;
                
                // B. LOW PASS FILTER (Exponential Moving Average)
                // Crush digital quantization noise
                filtered_speed = (actual_speed * 3 + raw_speed) >>> 2;
                actual_speed <= filtered_speed; // Save for next cycle
                
                // C. Calculate Error (Using the clean, filtered speed)
                error = $signed({16'b0, TARGET_SPEED_TICKS}) - filtered_speed;
                
                // D. Proportional Term
                p_term = error * $signed(KP_GAIN);
                
                // E. Integral Term & Anti-Windup
                next_integral = integral_error + (error * $signed(KI_GAIN));
                
                if (next_integral > (32'd1023 << GAIN_SHIFT))
                    next_integral = (32'd1023 << GAIN_SHIFT);
                else if (next_integral < 0) 
                    next_integral = 0; 
                
                integral_error = next_integral;
                
                // F. Final PI Output Math
                raw_pi_out = (p_term + integral_error) >>> GAIN_SHIFT;
                
                if (raw_pi_out > 32'd1023)
                    pi_modulation_out <= 10'd1023;
                else if (raw_pi_out < 0)
                    pi_modulation_out <= 10'd0;
                else
                    pi_modulation_out <= raw_pi_out[9:0];
            end
        end else begin
            dt_timer <= dt_timer + 1;
        end
    end

    // ==========================================
    // 6. Startup Sequence FSM
    // ==========================================
    reg [1:0] state = STATE_ALIGN;
    reg [31:0] fsm_timer = 0;
    reg [11:0] offset_angle = 0;
    
    reg [11:0] svpwm_angle_cmd;
    reg [9:0]  svpwm_mod_cmd;

    always @(posedge CLOCK_50) begin
        if (!KEY[0]) begin
            state <= STATE_ALIGN;
            fsm_timer <= 0;
            offset_angle <= 0;
            svpwm_angle_cmd <= 12'd0;
            svpwm_mod_cmd <= 10'd0;
        end else begin
            case (state)
                STATE_ALIGN: begin
                    svpwm_angle_cmd <= 12'd0;
                    svpwm_mod_cmd   <= ALIGN_MODULATION;
                    
                    if (fsm_timer >= CLOCK_FREQ * 3) begin
                        offset_angle <= elec_angle_raw;
                        fsm_timer <= 0;
                        state <= STATE_WAIT;
                    end else fsm_timer <= fsm_timer + 1;
                end
                
                STATE_WAIT: begin
                    svpwm_angle_cmd <= 12'd0;
                    svpwm_mod_cmd   <= 10'd0;
                    
                    if (fsm_timer >= CLOCK_FREQ * 1) begin
                        fsm_timer <= 0;
                        state <= STATE_RUN;
                    end else fsm_timer <= fsm_timer + 1;
                end
                
                STATE_RUN: begin
                    svpwm_angle_cmd <= (elec_angle_raw - offset_angle + 12'd1024) & 12'hFFF;
                    
                    // FEED PI OUTPUT TO INVERTER
                    svpwm_mod_cmd   <= pi_modulation_out; 
                end
                
                default: state <= STATE_ALIGN;
            endcase
        end
    end

    // ==========================================
    // 7. Status LEDs
    // ==========================================
    assign LED[1:0] = state;
    assign LED[7:2] = 6'b0;

    // ==========================================
    // 8. SVPWM Instantiation
    // ==========================================
    SVPWM inst_svpwm (
        .clk_50M(CLOCK_50),
        .rst_n(KEY[0]),
        .elec_angle(svpwm_angle_cmd),
        .modulation(svpwm_mod_cmd),
        .phase_a_plus(phase_a_plus), .phase_b_plus(phase_b_plus), .phase_c_plus(phase_c_plus),
        .phase_a_minus(phase_a_minus), .phase_b_minus(phase_b_minus), .phase_c_minus(phase_c_minus)
    );

endmodule