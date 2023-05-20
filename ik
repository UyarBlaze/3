module ir_receiver(
    input wire reset,
    input wire clk,         //примерно 5Мгц
    input wire ir_input,    //сигнал с микросхемы ИК приемника ILMS5360
    output reg [7:0]ir_cmd, //принятый от ИК приемника байт 
    output reg ir_cmd_ready //сигнал готовности принятого байта
);

//разделим входную тактовую частоту 5Мгц на 139
//получим последовательность коротких импульсов count_imp 
//с частотой 36Кгц
reg [7:0]cnt;
wire count_imp; assign count_imp = (cnt==138);
always @(posedge clk or posedge reset)
    if(reset)
        cnt<=0;
    else
        if(count_imp)
            cnt<=0;
        else
            cnt<=cnt+1;

//вместе с каждым импульсом count_imp запомним текущее значение
//сигнала от ??К приемника
reg ir_input_;
always @(posedge clk)
    if(count_imp)
        ir_input_ <= ir_input;

//обнаружение спада сигнала ИК приемника
//(спад - переход сигнала из "1" в "0")
//если сигнал стал нулем, а его предыдущее значение было единица
wire ir_falling_edge;
assign ir_falling_edge = (~ir_input) & ir_input_ & count_imp;

//счетчик, которым считаем длину положительного импульса
//от ИК приемника
reg [6:0]length;

//подсчитываем количество импульсов count_imp за время 
//положительного импульса от ИК применика ir_input, но
//не более 127, чтобы избежать переполнения счетчика
always @(posedge clk)
    if(ir_falling_edge)
        length <= 0;
    else
    if(ir_input & count_imp & (length<7'h7F) )
        length <= length+1;

//сдвиговый регистр, в котором накапливается принятый код
reg [7:0]shift_reg;

//по спаду сигнала ИК приемника ir_input принимаем решение
//о том, принят бит или нет.
//если длина импулься ir_input меньше 64, то мы приняли бит,
//а не префикс ИК пакета
//дальше, если длина импульса меньше 32, то принят ноль, а иначе 
//принята единица
always @(posedge clk or posedge reset)
begin
    if(reset)
        shift_reg <= 0;
    else
    if(ir_falling_edge)
    begin
        if(length<64)
            //получаем бит в сдвиговый регистр
            shift_reg <= {shift_reg[6:0],(length>32)};
    end
end        

//ведем подсчет принятых бит
reg [2:0]num_bits;
always @(posedge clk or posedge reset)
    if(reset)
        num_bits <= 0;
    else
    if(ir_falling_edge)
    begin
        if(length<64)
            num_bits <= num_bits+1; //принят бит
        else
            num_bits <= 0; //начало пакета
    end

//сигнал "седьмой бит принят" 
wire nbit7;
assign nbit7 = (num_bits==7);

//запоманаем сигнал "седьмой бит принят" по каждому фронту
//тактовой частоты
reg nbit7_;
always @(posedge clk)
    nbit7_ <= nbit7;
    
always @*
begin
    //формируем короткий импульс готовности принятого байта
    ir_cmd_ready = (~nbit7) & nbit7_;
    
    //принятый в сдвиговый регистр байт - это и есть то что нам нужно
    ir_cmd = shift_reg;
end

endmodule
