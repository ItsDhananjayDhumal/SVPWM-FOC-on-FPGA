`timescale 1ns / 1ps

module us_md (
    input  wire        CLOCK_50,
    input  wire [1:0]  KEY,       
   
    input  wire        ext_button,
    input  wire [4:0]  angle_btns,
   
    input  wire        enc_a,
    input  wire        enc_b,
    input  wire        enc_z,

    output wire        phase_a_plus, phase_a_minus,
    output wire        phase_b_plus, phase_b_minus,
    output wire        phase_c_plus, phase_c_minus,

    output wire [7:0]  LED,

    output wire [3:0]  dig_actual,
    output wire [7:0]  seg_actual,

    output wire [3:0]  dig_target,
    output wire [7:0]  seg_target
);

    parameter PPR                = 10000;
    parameter POLE_PAIRS         = 7;          
    parameter CLOCK_FREQ         = 50_000_000;

    parameter ALIGN_MODULATION  = 10'd200;  
    parameter ALIGN_PERIOD_MS   = 32'd1000;
    parameter ALIGN_PULSE_MS    = 32'd300;  
    parameter ALIGN_BEEP_FREQ   = 32'd1000;
    localparam MS_TICKS         = CLOCK_FREQ / 1000;
    localparam ALIGN_BEEP_LIMIT = (ALIGN_BEEP_FREQ > 0) ? (CLOCK_FREQ / (ALIGN_BEEP_FREQ * 2)) : 32'd0;

    parameter DEBOUNCE_MS       = 32'd20;
    localparam DEBOUNCE_LIMIT   = DEBOUNCE_MS * MS_TICKS;

    parameter DT_CYCLES         = 50_000;
    parameter GAIN_SHIFT        = 4'd8;

    parameter SPD_KP_GAIN       = 32'd2000;    
    parameter SPD_KI_GAIN       = 32'd10;
    parameter signed [31:0] MAX_SPD_MODULATION = 32'd400;
    parameter SPEED_RAMP_MS     = 16'd5;

    parameter POS_KP_GAIN       = 32'd80;  
    parameter POS_KI_GAIN       = 32'd1;    
    parameter POS_KD_GAIN       = 32'd30;  
    parameter signed [31:0] MAX_POS_MODULATION = 32'd250;

    localparam STATE_ALIGN     = 3'd0;
    localparam STATE_BEEP1     = 3'd1;
    localparam STATE_BEEP2     = 3'd2;
    localparam STATE_BEEP3     = 3'd3;
    localparam STATE_RUN_SPEED = 3'd4;
    localparam STATE_RUN_ANGLE = 3'd5;


    reg [31:0] mode_counter = 0;
    reg mode_state = 1'b1;
    reg mode_state_prev = 1'b1;

    always @(posedge CLOCK_50) begin
        mode_state_prev <= mode_state;
        if (ext_button != mode_state) begin
            if (mode_counter >= DEBOUNCE_LIMIT) begin
                mode_state <= ext_button;
                mode_counter <= 0;
            end else mode_counter <= mode_counter + 1;
        end else mode_counter <= 0;
    end
    wire mode_btn_pressed = (mode_state_prev == 1'b1 && mode_state == 1'b0); 

    reg [31:0] btn_counters [4:0];
    reg [4:0]  btn_state = 5'b11111;
    reg [4:0]  btn_state_prev = 5'b11111;
   
    genvar i;
    generate
        for (i=0; i<5; i=i+1) begin : BTN_DEBOUNCE
            always @(posedge CLOCK_50) begin
                if (!KEY[0]) begin
                    btn_counters[i] <= 0;
                    btn_state[i]    <= 1'b1;
                end else begin
                    if (angle_btns[i] != btn_state[i]) begin
                        if (btn_counters[i] >= DEBOUNCE_LIMIT) begin
                            btn_state[i] <= angle_btns[i];
                            btn_counters[i] <= 0;
                        end else btn_counters[i] <= btn_counters[i] + 1;
                    end else btn_counters[i] <= 0;
                end
            end
        end
    endgenerate

    always @(posedge CLOCK_50) btn_state_prev <= btn_state;
    wire [4:0] btn_pressed  = ~btn_state & btn_state_prev;  
    wire [4:0] btn_released = btn_state & ~btn_state_prev;  


    reg signed [15:0] target_speed_ticks = 16'd200;
    reg [15:0] mech_zero_offset = 0;
    reg [15:0] target_offset = 0;
    reg [2:0] state = STATE_ALIGN;

    always @(posedge CLOCK_50) begin
        if (!KEY[0]) begin
            target_speed_ticks <= 16'd200;
            target_offset <= 0;
            mech_zero_offset <= 0;
        end else begin
            if (state == STATE_RUN_SPEED) begin
                if (btn_pressed[0]) target_speed_ticks <= target_speed_ticks + 10;
                if (btn_pressed[1] && target_speed_ticks >= 10) target_speed_ticks <= target_speed_ticks - 10;
                if (btn_pressed[2]) target_speed_ticks <= target_speed_ticks + 1;
                if (btn_pressed[3] && target_speed_ticks >= 1)  target_speed_ticks <= target_speed_ticks - 1;
            end
            else if (state == STATE_RUN_ANGLE) begin
                if (btn_released[4]) begin
                    mech_zero_offset <= count;
                    target_offset <= 0;
                end else if (btn_state[4]) begin
                    if (btn_pressed[0]) target_offset <= 0;
                    if (btn_pressed[1]) target_offset <= PPR / 4;
                    if (btn_pressed[2]) target_offset <= PPR / 2;
                    if (btn_pressed[3]) target_offset <= (PPR * 3) / 4;
                end
            end
        end
    end


    reg [15:0] count = 0;
    reg [2:0] a_sync = 0, b_sync = 0;

    always @(posedge CLOCK_50) begin
        a_sync <= {a_sync[1:0], enc_a};
        b_sync <= {b_sync[1:0], enc_b};
    end

    wire a_edge = a_sync[1] ^ a_sync[2];
    wire b_edge = b_sync[1] ^ b_sync[2];
    wire enc_dir = a_sync[1] ^ b_sync[2];

    always @(posedge CLOCK_50) begin
        if (!KEY[0]) count <= 0;
        else if (a_edge || b_edge) begin
            if (enc_dir) begin
                if (count >= PPR - 1) count <= 0; else count <= count + 1;
            end else begin
                if (count == 0) count <= PPR - 1; else count <= count - 1;
            end
        end
    end

    wire [31:0] fast_angle_mult = {16'b0, count} * 32'd187905;
    wire [11:0] elec_angle_raw  = fast_angle_mult[27:16];

    reg [31:0] dt_timer = 0;
    reg tick_1ms = 0;
    always @(posedge CLOCK_50) begin
        if (dt_timer >= DT_CYCLES - 1) begin
            dt_timer <= 0; tick_1ms <= 1'b1;
        end else begin
            dt_timer <= dt_timer + 1; tick_1ms <= 1'b0;
        end
    end


    reg [31:0] beep_limit = 0;
    reg [31:0] beep_timer = 0;
    reg beep_state = 1'b1;
    reg align_active_flag = 1'b0;

    always @(*) begin
        case (state)
            STATE_ALIGN: beep_limit = align_active_flag ? ALIGN_BEEP_LIMIT : 32'd0;
            STATE_BEEP1: beep_limit = CLOCK_FREQ / (1000 * 2);
            STATE_BEEP2: beep_limit = CLOCK_FREQ / (1500 * 2);
            STATE_BEEP3: beep_limit = CLOCK_FREQ / (2000 * 2);
            default:     beep_limit = 32'd0;
        endcase
    end

    always @(posedge CLOCK_50) begin
        if (beep_limit == 0) begin
            beep_timer <= 0; beep_state <= 1'b1;
        end else begin
            if (beep_timer >= beep_limit - 1) begin
                beep_timer <= 0; beep_state <= ~beep_state;
            end else beep_timer <= beep_timer + 1;
        end
    end


    reg [15:0] prev_count = 0;
    reg signed [15:0] actual_speed = 0;
    wire signed [16:0] count_diff = $signed({1'b0, count}) - $signed({1'b0, prev_count});
    reg signed [31:0] integral_error_spd = 0;
    reg signed [31:0] pi_modulation_out = 0;
    reg signed [15:0] current_target_speed = 0;
    reg [15:0] ramp_timer = 0;

    wire [31:0] calc_target = mech_zero_offset + target_offset;
    wire [15:0] target_count = (calc_target >= PPR) ? (calc_target - PPR) : calc_target[15:0];
    reg signed [31:0] integral_error_pos = 0;
    reg signed [15:0] prev_error_pos = 0;
    reg signed [31:0] pid_modulation_out = 0;
    wire signed [31:0] pid_modulation_out_neg = -pid_modulation_out;

    always @(posedge CLOCK_50) begin
        if (!KEY[0]) begin
            prev_count <= 0; actual_speed <= 0;
            integral_error_spd <= 0; pi_modulation_out <= 0;
            integral_error_pos <= 0; prev_error_pos <= 0; pid_modulation_out <= 0;
            current_target_speed <= 0; ramp_timer <= 0;
        end
        else if (tick_1ms) begin
            // PI Speed Math
            begin : PI_MATH
                reg signed [15:0] raw_speed;
                reg signed [15:0] filtered_speed;
                reg signed [31:0] error, next_integral, raw_pi_out;

                if (count_diff > $signed(PPR/2))       raw_speed = count_diff - $signed(PPR);
                else if (count_diff < -$signed(PPR/2)) raw_speed = count_diff + $signed(PPR);
                else                                   raw_speed = count_diff;
                prev_count <= count;

                filtered_speed = (actual_speed * 3 + raw_speed) >>> 2;
                actual_speed  <= filtered_speed;

                if (state == STATE_RUN_SPEED) begin
                    if (ramp_timer >= SPEED_RAMP_MS - 1) begin
                        ramp_timer <= 0;
                        if (current_target_speed < target_speed_ticks) current_target_speed <= current_target_speed + 1;
                        else if (current_target_speed > target_speed_ticks) current_target_speed <= current_target_speed - 1;
                    end else ramp_timer <= ramp_timer + 1;
                end else current_target_speed <= 0;

                error = current_target_speed - filtered_speed;
                next_integral = integral_error_spd + (error * $signed(SPD_KI_GAIN));
                if (next_integral > (MAX_SPD_MODULATION <<< GAIN_SHIFT)) next_integral = (MAX_SPD_MODULATION <<< GAIN_SHIFT);
                else if (next_integral < 0) next_integral = 0;
                integral_error_spd <= next_integral;

                raw_pi_out = ((error * $signed(SPD_KP_GAIN)) + next_integral) >>> GAIN_SHIFT;
                if (raw_pi_out > MAX_SPD_MODULATION) pi_modulation_out <= MAX_SPD_MODULATION;
                else if (raw_pi_out < 0) pi_modulation_out <= 0;
                else pi_modulation_out <= raw_pi_out;
            end

            // PID Angle Math
            begin : PID_MATH
                reg signed [31:0] raw_err, error, next_int, raw_pid;
                raw_err = $signed({1'b0, target_count}) - $signed({1'b0, count});
                if (raw_err > (PPR/2)) error = raw_err - PPR;
                else if (raw_err < -($signed(PPR/2))) error = raw_err + PPR;
                else error = raw_err;
               
                next_int = integral_error_pos + (error * $signed(POS_KI_GAIN));
                if (next_int > (MAX_POS_MODULATION <<< GAIN_SHIFT)) next_int = (MAX_POS_MODULATION <<< GAIN_SHIFT);
                else if (next_int < -(MAX_POS_MODULATION <<< GAIN_SHIFT)) next_int = -(MAX_POS_MODULATION <<< GAIN_SHIFT);
                integral_error_pos <= next_int;
               
                raw_pid = ((error * $signed(POS_KP_GAIN)) + next_int + ((error - prev_error_pos) * $signed(POS_KD_GAIN))) >>> GAIN_SHIFT;
                prev_error_pos <= error;
                if (raw_pid > MAX_POS_MODULATION) pid_modulation_out <= MAX_POS_MODULATION;
                else if (raw_pid < -MAX_POS_MODULATION) pid_modulation_out <= -MAX_POS_MODULATION;
                else pid_modulation_out <= raw_pid;
            end
           
            if (state != STATE_RUN_SPEED) integral_error_spd <= 0;
            if (state != STATE_RUN_ANGLE || !btn_state[4]) integral_error_pos <= 0;
        end
    end


    reg [31:0] fsm_timer = 0;
    reg [11:0] foc_offset_angle = 0;
    reg [11:0] svpwm_angle_cmd;
    reg [9:0]  svpwm_mod_cmd;

    always @(posedge CLOCK_50) begin
        if (!KEY[0]) begin
            state <= STATE_ALIGN; fsm_timer <= 0; foc_offset_angle <= 0;
            svpwm_angle_cmd <= 12'd0; svpwm_mod_cmd <= 10'd0; align_active_flag <= 1'b0;
        end else begin
            case (state)
                STATE_ALIGN: begin
                    svpwm_angle_cmd <= 12'd0;
                    if (fsm_timer < (ALIGN_PULSE_MS * MS_TICKS)) begin
                        align_active_flag <= 1'b1; svpwm_mod_cmd <= ALIGN_MODULATION;
                        if (tick_1ms) foc_offset_angle <= (foc_offset_angle * 15 + elec_angle_raw) >> 4;
                    end else begin
                        align_active_flag <= 1'b0; svpwm_mod_cmd <= 10'd0;
                    end
                    if (fsm_timer >= (ALIGN_PERIOD_MS * MS_TICKS) - 1) fsm_timer <= 0;
                    else fsm_timer <= fsm_timer + 1;
                    if (mode_btn_pressed) begin state <= STATE_BEEP1; fsm_timer <= 0; align_active_flag <= 1'b0; end
                end
                STATE_BEEP1: begin
                    svpwm_angle_cmd <= 12'd0; svpwm_mod_cmd <= ALIGN_MODULATION;
                    if (fsm_timer >= CLOCK_FREQ / 3) begin state <= STATE_BEEP2; fsm_timer <= 0; end
                    else fsm_timer <= fsm_timer + 1;
                end
                STATE_BEEP2: begin
                    svpwm_angle_cmd <= 12'd0; svpwm_mod_cmd <= ALIGN_MODULATION;
                    if (fsm_timer >= CLOCK_FREQ / 3) begin state <= STATE_BEEP3; fsm_timer <= 0; end
                    else fsm_timer <= fsm_timer + 1;
                end
                STATE_BEEP3: begin
                    svpwm_angle_cmd <= 12'd0; svpwm_mod_cmd <= ALIGN_MODULATION;
                    if (fsm_timer >= CLOCK_FREQ / 3) begin state <= STATE_RUN_SPEED; end
                    else fsm_timer <= fsm_timer + 1;
                end
                STATE_RUN_SPEED: begin
                    svpwm_angle_cmd <= (elec_angle_raw - foc_offset_angle + 12'd1024) & 12'hFFF;
                    svpwm_mod_cmd   <= pi_modulation_out[9:0];
                    if (mode_btn_pressed) state <= STATE_RUN_ANGLE;
                end
                STATE_RUN_ANGLE: begin
                    if (!btn_state[4]) svpwm_mod_cmd <= 10'd0;
                    else begin
                        if (pid_modulation_out >= 0) begin
                            svpwm_angle_cmd <= (elec_angle_raw - foc_offset_angle + 12'd1024) & 12'hFFF;
                            svpwm_mod_cmd   <= pid_modulation_out[9:0];
                        end else begin
                            svpwm_angle_cmd <= (elec_angle_raw - foc_offset_angle + 12'd3072) & 12'hFFF;
                            svpwm_mod_cmd   <= pid_modulation_out_neg[9:0];
                        end
                    end
                    if (mode_btn_pressed) state <= STATE_RUN_SPEED;
                end
                default: state <= STATE_ALIGN;
            endcase
        end
    end

    assign LED[2:0] = state;
    assign LED[7:3] = 5'b0;


    wire svpwm_a_plus, svpwm_a_minus, svpwm_b_plus, svpwm_b_minus, svpwm_c_plus, svpwm_c_minus;
    SVPWM inst_svpwm (
        .clk_50M(CLOCK_50), .rst_n(KEY[0]), .en(beep_state),
        .elec_angle(svpwm_angle_cmd), .modulation(svpwm_mod_cmd),
        .phase_a_plus(svpwm_a_plus), .phase_b_plus(svpwm_b_plus), .phase_c_plus(svpwm_c_plus),
        .phase_a_minus(svpwm_a_minus), .phase_b_minus(svpwm_b_minus), .phase_c_minus(svpwm_c_minus)
    );

    wire freewheel_active = (state == STATE_RUN_ANGLE) && (!btn_state[4]);
    assign phase_a_plus  = freewheel_active ? 1'b0 : svpwm_a_plus;
    assign phase_a_minus = freewheel_active ? 1'b0 : svpwm_a_minus;
    assign phase_b_plus  = freewheel_active ? 1'b0 : svpwm_b_plus;
    assign phase_b_minus = freewheel_active ? 1'b0 : svpwm_b_minus;
    assign phase_c_plus  = freewheel_active ? 1'b0 : svpwm_c_plus;
    assign phase_c_minus = freewheel_active ? 1'b0 : svpwm_c_minus;

    wire [15:0] norm_count = (count >= mech_zero_offset) ? (count - mech_zero_offset) : (count + PPR - mech_zero_offset);
    wire [15:0] actual_deg_x10 = (norm_count * 36) / 100;
    wire [15:0] target_deg_x10 = (target_offset * 36) / 100;
    wire is_angle_mode = (state == STATE_RUN_ANGLE);
   
    wire signed [15:0] disp_actual_data = is_angle_mode ? actual_deg_x10 : actual_speed;
    wire signed [15:0] disp_target_data = is_angle_mode ? target_deg_x10 : target_speed_ticks;

    seven_seg_rpm_driver inst_actual_display (
        .clk_50M(CLOCK_50), .rst_n(KEY[0]), .speed_ticks(disp_actual_data),
        .dig_out(dig_actual), .seg_out(seg_actual)
    );
    seven_seg_rpm_driver inst_target_display (
        .clk_50M(CLOCK_50), .rst_n(KEY[0]), .speed_ticks(disp_target_data),
        .dig_out(dig_target), .seg_out(seg_target)
    );

endmodule