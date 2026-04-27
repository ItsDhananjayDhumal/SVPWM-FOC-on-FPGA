module capwm (
    input  wire clk,               
    input  wire rst_n,             
    input  wire en,                // NEW: Enable signal for acoustic chopping
    input  wire [11:0] duty_cycle, 
    output wire pwm_out 
);

    localparam MAX_COUNT = 4095;

    reg [11:0] counter;
    reg count_dir;

    initial begin
        counter <= 0;
        count_dir <= 1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter   <= 12'b0;
            count_dir <= 1'b1;
        end else begin
            if (count_dir) begin
                if (counter == MAX_COUNT - 1'b1) begin
                    counter   <= counter + 1'b1;
                    count_dir <= 1'b0;
                end else begin
                    counter   <= counter + 1'b1;
                end
            end 
            else begin
                if (counter == 12'd1) begin
                    counter   <= counter - 1'b1;
                    count_dir <= 1'b1;
                end else begin
                    counter   <= counter - 1'b1;
                end
            end
        end
    end

    wire [11:0] safe_duty;
    assign safe_duty = (duty_cycle > MAX_COUNT) ? MAX_COUNT[11:0] : duty_cycle;

    // Modulate the output with the enable signal
    assign pwm_out = en ? (safe_duty > counter) : 1'b0;

endmodule