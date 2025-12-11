# stm-cpld-usage
1. 一句话功能（你可以直接背）

This program measures the frequency of a pulse signal by counting its edges with TIM2, using TIM6 as a 1-second gate timer. The result is printed over UART every second.

中文顺一下：

TIM3 产生一个 PWM 测试方波（或者以后换成 comparator 输出）；

这个方波进 TIM2 的外部时钟输入（ETR2，PB0）；

TIM2 把每一秒内的“上升沿/脉冲数”累加起来；

TIM6 每 1 秒进一次中断：读 TIM2 当前计数 → 算频率 → 清零；

主循环里用 printf 每秒打印一次频率。

2. 全局变量（一定要会解释）
volatile uint32_t g_edge_count = 0;   // Pulse count within one gate window
volatile float    g_freq_hz    = 0.0f; // Calculated frequency in Hz
volatile uint32_t g_gate_ticks = 0;   // How many times TIM6 interrupt has fired


你可以这样说：

g_edge_count：上一个闸门时间（比如 1 s）内，TIM2 数到的脉冲个数；

g_freq_hz：根据 g_edge_count 算出来的频率（Hz）；

g_gate_ticks：TIM6 中断被调用的次数（调试用，看 gate 是否是每秒一次）；

都是 volatile，因为中断里在改，主循环在读，防止编译器优化掉内存访问。

3. main() 的关键逻辑（你只要把这些讲清楚就够）
3.1 初始化 + 启动定时器
MX_GPIO_Init();
MX_ICACHE_Init();
MX_COMP1_Init();
MX_TIM2_Init();
MX_TIM6_Init();
MX_TIM3_Init();

/* USER CODE BEGIN 2 */
HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_1);
HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_3);

// Reset TIM2 counter and start it
__HAL_TIM_SET_COUNTER(&htim2, 0);
HAL_TIM_Base_Start(&htim2);

// Start TIM6 base timer with interrupt
HAL_TIM_Base_Start_IT(&htim6);


你可以这么讲：

MX_*_Init()：Cube 自动生成的外设初始化函数；

TIM3：配置成 PWM 输出，用作测试信号源（之后可以替换成比较器输出）；

TIM2：

在 MX_TIM2_Init() 里已经配置成 外部时钟模式 2 (ETRMODE2)；

也就是说它的时钟来源不是内部时钟，而是 PB0 上来的外部脉冲；

HAL_TIM_Base_Start(&htim2) 之后，TIM2 开始对外部脉冲计数。

TIM6：

配成大约 1 秒一次中断（通过 prescaler + period）；

用来做闸门时间（gate time）。

3.2 串口 + 主循环打印结果
// COM1 initialisation (115200, 8N1) ...
BSP_COM_Init(COM1, &BspCOMInit);

while (1)
{
    printf("GateTicks = %lu, Freq ≈ %.2f Hz  (Edges = %lu)\r\n",
           (unsigned long)g_gate_ticks,
           g_freq_hz,
           (unsigned long)g_edge_count);

    HAL_Delay(1000);   // Print once per second
}


你可以说：

In the main loop I simply print the latest measurement:
how many times the gate interrupt has fired (g_gate_ticks),
the measured frequency in Hz (g_freq_hz),
and the raw edge count (g_edge_count).
I add a 1-second delay so we only print once per second.

4. 各个定时器的配置作用（老师很可能问的点）
4.1 TIM2：外部时钟计数器（频率计数的核心）
htim2.Instance = TIM2;
htim2.Init.Prescaler = 0;
htim2.Init.CounterMode = TIM_COUNTERMODE_UP;
htim2.Init.Period = 4294967295;  // 32-bit max
...
sClockSourceConfig.ClockSource = TIM_CLOCKSOURCE_ETRMODE2;
sClockSourceConfig.ClockPolarity = TIM_CLOCKPOLARITY_NONINVERTED;
...
HAL_TIM_ConfigClockSource(&htim2, &sClockSourceConfig);


解释要点：

TIM2 配成 32 位向上计数器（Period = 0xFFFFFFFF）；

时钟源：TIM_CLOCKSOURCE_ETRMODE2 = 从 ETR2 引脚（PB0）进来的外部脉冲；

Prescaler = 0：每一个外部脉冲都让计数器 +1；

所以：TIM2 counter = 外部信号的边沿数。

如果老师问“PB0 的信号是哪来的？”你可以说：

In our lab setup, PB0 is connected to either the PWM output of TIM3 or the output of the comparator (COMP1), which shapes the analog Doppler signal into a digital pulse train.

4.2 TIM3：PWM 测试信号
htim3.Instance = TIM3;
htim3.Init.Prescaler = 999;
htim3.Init.Period    = 9;
...
HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_1);
HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_3);


要点：

TIM3 配成 PWM 模式；

频率公式：

𝑓
PWM
=
𝑓
timer clock
(
𝑃
𝑟
𝑒
𝑠
𝑐
𝑎
𝑙
𝑒
𝑟
+
1
)
×
(
𝑃
𝑒
𝑟
𝑖
𝑜
𝑑
+
1
)
f
PWM
	​

=
(Prescaler+1)×(Period+1)
f
timer clock
	​

	​


在实验中，这个 PWM 通过硬件连到 PB0 / comparator，用来模拟一个已知频率的方波，让你验证频率计数是否正确。

4.3 TIM6：闸门时间（gate timer）
htim6.Instance = TIM6;
htim6.Init.Prescaler = 3999;
htim6.Init.Period    = 999;
...
HAL_TIM_Base_Start_IT(&htim6);


解释：

TIM6 作为基本定时器，只用来周期性触发中断；

通过 Prescaler 和 Period 设置，让其中断周期 ≈ 1 秒（具体看时钟频率）；

每次 TIM6 中断 → 构成一个“闸门结束”的时刻：读计数、算频率、清零，开始下一秒。

5. 中断回调：频率是怎么算出来的？

关键函数：

void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
    // ① Keep HAL's system tick for TIM17
    if (htim->Instance == TIM17)
    {
        HAL_IncTick();
    }

    // ② Our 1-second gate on TIM6
    if (htim->Instance == TIM6)
    {
        g_gate_ticks++;

        uint32_t count = __HAL_TIM_GET_COUNTER(&htim2);

        g_edge_count = count;

        // window = 1.0 s → F ≈ edges / 1s
        g_freq_hz = (float)count;

        // Reset counter for the next gate interval
        __HAL_TIM_SET_COUNTER(&htim2, 0);
    }
}


你讲的时候可以说：

HAL_TIM_PeriodElapsedCallback is called whenever any timer with interrupt enabled elapses.
We first keep the default HAL behaviour for TIM17, which updates the system tick.
Then we check for TIM6:
every time TIM6 reaches its period (about 1 second), we read the current value of TIM2 counter using __HAL_TIM_GET_COUNTER, which gives us the number of edges within this gate time.
Since the gate time is 1.0 second, the frequency in Hz is simply equal to the edge count.
We store the count in g_edge_count, convert it to float as g_freq_hz, and then reset TIM2 counter to zero for the next gate interval.

如果老师问“为什么不直接在中断里 printf？”，你可以说：

Printing inside the interrupt is not recommended because it can block and delay other interrupts. Here we just update global variables and do the printing in the main loop.

6. viva 用的“骨架代码版本”（可以练着背）

你不需要背 Cube 全部初始化，只要记住这几个关键结构就很好用了：

// Global variables
volatile uint32_t g_edge_count = 0;
volatile float    g_freq_hz    = 0.0f;
volatile uint32_t g_gate_ticks = 0;

int main(void)
{
    HAL_Init();
    SystemClock_Config();
    SystemPower_Config();

    MX_GPIO_Init();
    MX_ICACHE_Init();
    MX_COMP1_Init();   // comparator for Doppler signal
    MX_TIM2_Init();    // external clock counter
    MX_TIM3_Init();    // PWM test signal
    MX_TIM6_Init();    // gate timer
    MX_USARTx_Init();  // or BSP_COM_Init(...)

    // Start PWM output for test
    HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_1);

    // Start external-clock counter TIM2
    __HAL_TIM_SET_COUNTER(&htim2, 0);
    HAL_TIM_Base_Start(&htim2);

    // Start gate timer TIM6 with interrupt
    HAL_TIM_Base_Start_IT(&htim6);

    while (1)
    {
        printf("Gate = %lu, Freq ≈ %.2f Hz (Edges = %lu)\r\n",
               (unsigned long)g_gate_ticks,
               g_freq_hz,
               (unsigned long)g_edge_count);
        HAL_Delay(1000);
    }
}

// Timer callback
void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
    if (htim->Instance == TIM17)
    {
        HAL_IncTick();
    }

    if (htim->Instance == TIM6)
    {
        g_gate_ticks++;

        uint32_t count = __HAL_TIM_GET_COUNTER(&htim2);
        g_edge_count   = count;
        g_freq_hz      = (float)count;   // gate = 1 s

        __HAL_TIM_SET_COUNTER(&htim2, 0);
    }
}


建议你自己关着代码手写一遍类似的结构，特别是：

全局变量定义

main 里启动 TIM2 / TIM6 的那几行

callback 里读 TIM2 → 算频率 → 清零

7. viva 常见问题 + 回答模板
Q1. 这个程序是怎么测频率的？

TIM2 is configured as an external-clock counter. Its clock source comes from the ETR2 pin, where we feed the pulse signal.
TIM6 acts as a gate timer with a 1-second period.
Every time TIM6 interrupt fires, we read how many edges TIM2 has counted during the last gate interval.
Since the gate is 1 second, the frequency in Hz is simply the number of edges per second.

Q2. 为什么要用 volatile？

These variables are shared between the interrupt context and the main loop.
Without volatile, the compiler might keep their values in registers and never reload from memory, so the main loop could see stale values.
volatile forces the compiler to always read and write the actual memory location.

Q3. 如果想把闸门时间从 1 s 改成 0.5 s 或 2 s，要改哪里？

The gate time is determined by the TIM6 update period, which depends on its prescaler and auto-reload value.
To change the gate duration, we modify htim6.Init.Prescaler and htim6.Init.Period in MX_TIM6_Init.
After that, in the callback, we should adjust the frequency formula to freq = count / gate_time, not just freq = count.

举个例子：

gate = 0.5 s → g_freq_hz = count / 0.5f;

gate = 2 s → g_freq_hz = count / 2.0f;

Q4. TIM3 的 PWM 频率怎么计算？

The PWM frequency for TIM3 is:

𝑓
PWM
=
𝑓
timer clock
(
𝑃
𝑟
𝑒
𝑠
𝑐
𝑎
𝑙
𝑒
𝑟
+
1
)
×
(
𝑃
𝑒
𝑟
𝑖
𝑜
𝑑
+
1
)
f
PWM
	​

=
(Prescaler+1)×(Period+1)
f
timer clock
	​

	​

.
With Prescaler = 999 and Period = 9, we divide the timer clock by 
1000
×
10
=
10
,
000
1000×10=10,000.
So the PWM frequency is f_timer / 10,000.
If the timer clock is, for example, 4 MHz, then the PWM frequency is 400 Hz.

Q5. COMP1 在这里起什么作用？

（虽然这段代码里还没 HAL_COMP_Start，但概念上你要会说）

COMP1 is configured as a comparator that converts the analog Doppler signal from the radar into a digital pulse train.
The positive input is connected to the signal, the negative input to a reference voltage.
Its digital output can then be routed to a timer input, for example TIM2 ETR, so that TIM2 counts pulses corresponding to the Doppler frequency.

8. 你现在可以怎么练这份代码

几个小任务，你做一遍，这个实验就稳了：

不看代码，画一张小流程图：
“脉冲信号 → TIM2 计数 → TIM6 闸门 → 中断里读计数 → 频率 → printf”。

手写一个简化版 main + callback，像我上面那段“骨架代码”。

对着你的同学 / 空气 / 玩偶，尝试用 30 秒解释：
“为什么用 TIM2 + TIM6 就能实现频率计数器？”
1. 一句话功能 + 整体流程（viva 开口就这么说）

英文版可以这么背：

This program uses TIM6 to trigger ADC1 at 1 kHz, collects 1024 voltage samples, then performs a 1024-point FFT using CMSIS-DSP. It finds the dominant frequency peak and converts it into speed, then prints the result over UART at 115200 baud.

中文顺一下：

TIM6 定时器产生 1 kHz 中断 →

在中断里启动 ADC，采一点评到 g_adc_samples[] 缓冲区 →

收集满 1024 点后，在主循环里：

计算 mean / min / max

去直流，把实数数据放到复数 FFT 输入

用 CMSIS-DSP 做 1024 点 FFT

求每个频率点的幅度，找最大峰值频率

把频率转成速度，printf 通过串口发出去

清标志，再开始下一轮采样

你在 viva 只要把这条线顺着讲一遍，老师就知道你是“懂整个系统”，不是只会改局部。

2. 全局变量 & FFT 缓冲区

关键部分（你要知道每个变量干嘛）：

#define FFT_SIZE       1024                 // Number of samples for FFT
#define SAMPLE_RATE_HZ 1000.0f              // Sampling rate in Hz (match TIM6)

float g_adc_samples[FFT_SIZE];              // Time-domain samples (voltage)

float g_fft_input[2 * FFT_SIZE];           // [Re0, Im0, Re1, Im1, ...]
float g_fft_mag[FFT_SIZE];                 // Magnitude for each FFT bin

volatile uint32_t g_sample_index = 0;      // Current index in g_adc_samples
volatile uint8_t  g_buffer_full  = 0;      // Flag: 1 when FFT_SIZE samples collected

arm_cfft_instance_f32 g_cfft_instance;


你可以这么解释：

FFT_SIZE：FFT 点数 = 1024

SAMPLE_RATE_HZ：采样频率 = 1 kHz（由 TIM6 控制，后面会讲）

g_adc_samples[]：存储每次中断采到的电压（时域数据）

g_fft_input[]：FFT 的复数输入数组，CMSIS 要求：实部 / 虚部交替存放

g_fft_mag[]：存 FFT 后每个频率点的幅度

g_sample_index：当前已经存了多少点

g_buffer_full：采样满了 1024 点就置 1，通知主循环可以做 FFT 了

volatile：因为这两个变量在中断里修改，在主循环里读取，告诉编译器不要乱优化

viva 里 “为什么用 volatile？” 是高频题，一定要会说。

3. main() 里你要真的懂的几件事

你不需要把自动生成的那堆 SystemClock_Config 背下来，老师也知道那是 Cube 写的。
你要重点盯这些地方：

3.1 外设初始化 + 启动定时器
MX_GPIO_Init();
MX_ICACHE_Init();
MX_ADC1_Init();
MX_TIM6_Init();

/* USER CODE BEGIN 2 */
HAL_TIM_Base_Start_IT(&htim6);          // Start TIM6 with interrupt
arm_cfft_init_f32(&g_cfft_instance, FFT_SIZE);


你要能说：

We configure GPIO, ADC1 and TIM6, then start TIM6 in interrupt mode using HAL_TIM_Base_Start_IT. TIM6 will generate an interrupt periodically, and in the callback we trigger one ADC conversion per interrupt.
Then we initialize the CMSIS FFT instance for a 1024-point FFT.

3.2 串口初始化（为了 printf 输出）
BspCOMInit.BaudRate   = 115200;
...
BSP_COM_Init(COM1, &BspCOMInit);


一句话就行：用 COM1 配成 115200 波特率，这样 printf 可以把结果发到串口终端。

3.3 FFT 库初始化（这块你容易被问）
arm_status st = arm_cfft_init_f32(&g_cfft, FFT_SIZE);
if (st != ARM_MATH_SUCCESS)
{
    printf("FFT init failed! status = %d\r\n", st);
}
else
{
    printf("FFT init OK\r\n");
}


你可以说：

We call arm_cfft_init_f32 to initialize the FFT structure with the correct size. This sets internal twiddle factors and bit-reversal tables. We also check the return status to ensure the FFT instance is valid before we use it.

（顺带一说：你这里有两个 FFT 实例 g_cfft 和 g_cfft_instance，实际用一个就够了，viva 时你可以只提你真正用的那个。）

3.4 主循环里最重要的 if 块（FFT + 频率 + 速度）

这一段是整个项目的“灵魂”，你要非常熟：

while (1)
{
    if (g_buffer_full)
    {
        HAL_TIM_Base_Stop_IT(&htim6);   // Stop TIM6 to avoid overwriting buffer

        // 1) Mean / min / max
        float sum   = 0.0f;
        float min_v = g_adc_samples[0];
        float max_v = g_adc_samples[0];

        for (uint32_t i = 0; i < FFT_SIZE; i++)
        {
            float v = g_adc_samples[i];
            sum += v;
            if (v < min_v) min_v = v;
            if (v > max_v) max_v = v;
        }
        float mean = sum / (float)FFT_SIZE;

        // 2) Prepare FFT input: remove DC, make complex
        for (uint32_t i = 0; i < FFT_SIZE; i++)
        {
            float v = g_adc_samples[i] - mean;
            g_fft_input[2 * i]     = v;      // Real part
            g_fft_input[2 * i + 1] = 0.0f;   // Imag part
        }

        // 3) FFT + magnitude
        arm_cfft_f32(&g_cfft, g_fft_input, 0, 1);
        arm_cmplx_mag_f32(g_fft_input, g_fft_mag, FFT_SIZE);

        // 4) Find peak in 1..N/2-1
        uint32_t peak_index = 1;
        float    peak_val   = g_fft_mag[1];

        for (uint32_t i = 2; i < FFT_SIZE / 2; i++)
        {
            if (g_fft_mag[i] > peak_val)
            {
                peak_val   = g_fft_mag[i];
                peak_index = i;
            }
        }

        float freq_res  = SAMPLE_RATE_HZ / (float)FFT_SIZE;   // Frequency resolution
        float peak_freq = freq_res * (float)peak_index;       // Dominant frequency

        float speed_mps = peak_freq / 70.0f;                  // Convert to speed

        // --- 分类输出（你现在这段逻辑其实写得有点怪）---
        if (peak_freq < 30.0f) {
            speed_mps = 0;          // 输出 00
        }
        else if (peak_freq < 99.0f && peak_freq > 98.0f) {
            speed_mps = 0;          // 这段按你之前说的需求应该改成 “> 某个频率时输出 9.9”
        }
        else {
            speed_mps = (int)(speed_mps * 10);   // 变成两位整数
        }

        printf("%02d\r\n", (int)(speed_mps));

        // 5) Reset for next block
        g_sample_index = 0;
        g_buffer_full  = 0;
        HAL_TIM_Base_Start_IT(&htim6);
        HAL_Delay(200);
    }

    HAL_Delay(50);        // Idle delay
}


你解释的时候可以按这 5 步讲：

停掉 TIM6：防止我们做 FFT 时，中断继续进来把数据覆盖了。

算 mean / min / max：可以了解信号幅度，也用于去掉 DC。

去 DC & 组复数数组：
实部 = 样本 - 均值，虚部 = 0。

FFT & magnitude：

arm_cfft_f32 做复数 FFT

arm_cmplx_mag_f32 把每个频点的复数幅度 -> 实数

找峰值频率：

只在 1 .. FFT_SIZE/2 - 1 搜索（正频率部分）

用 采样率 / FFT_SIZE 得到频率分辨率

peak_freq = bin_index * freq_res

再加一句：

Then I convert the dominant frequency into speed using a simple linear relationship, and print a 2-digit integer over UART.

4. 定时器回调：采样是怎么完成的

这是 viva 很爱问的地方：“你是怎么做到定时采样的？”

void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
    if (htim->Instance == TIM6)
    {
        HAL_ADC_Start(&hadc1);

        if (HAL_ADC_PollForConversion(&hadc1, 10) == HAL_OK)
        {
            adc_raw     = HAL_ADC_GetValue(&hadc1);
            adc_voltage = (float)adc_raw * 3.3f / 4095.0f;

            if (!g_buffer_full)
            {
                g_adc_samples[g_sample_index] = adc_voltage;
                g_sample_index++;

                if (g_sample_index >= FFT_SIZE)
                {
                    g_buffer_full = 1;
                }
            }
        }

        HAL_ADC_Stop(&hadc1);
    }

    if (htim->Instance == TIM17)
    {
        HAL_IncTick();
    }
}


你可以这样讲：

TIM6 is configured to generate an interrupt at 1 kHz.
In the TIM6 branch of HAL_TIM_PeriodElapsedCallback, I start ADC1, poll for one conversion, read the raw value, convert it to a voltage, and store it into the sample buffer.
I increment g_sample_index each time, and when it reaches 1024 I set g_buffer_full = 1 to notify the main loop that one full block is ready for FFT.

额外知识点：

采样频率 = TIM6 中断频率 = 1 kHz

ADC 设置为 software start，但我们是在每次 TIM6 中断里手动启动一次 → 等价于“由 TIM6 控制采样时刻”。

5. viva 可能会问的问题 + 模板答案
Q1. 采样频率是多少？怎么来的？

The sampling frequency is 1 kHz.
TIM6 is configured with a certain prescaler and period so that the update event occurs every 1 ms.
We start one ADC conversion in each TIM6 interrupt, so effectively the ADC sampling rate is 1 kHz.

（如果老师追问 prescaler 和 period 的关系，你可以说：
f_tim = f_clk / (Prescaler+1)，再除以 (Period+1) 得到中断频率，不过这部分具体数值可以看 Cube 配置，不一定要全背。）

Q2. 为什么 FFT 只在 1 .. FFT_SIZE/2-1 范围找峰？

For a real input signal, the FFT output is symmetric: the second half corresponds to negative frequencies.
The useful positive frequencies lie in bins 1 to N/2-1, so we search only in that range to avoid duplicate peaks and the DC component at bin 0.

Q3. 为什么要减掉 mean（去直流）？

The DC component appears at bin 0 in the FFT and can have a large magnitude.
If we don't remove it, the DC peak might dominate and make it harder to detect the true AC frequency component.
Subtracting the mean centers the signal around zero and reduces the DC term.

Q4. 频率分辨率是多少？跟什么有关？

The frequency resolution is Δf = Fs / N, where Fs is the sampling rate and N is the FFT size.
Here Fs = 1000 Hz and N = 1024, so the resolution is about 0.976 Hz per bin.

Q5. 为什么这些变量要用 volatile？

指 g_sample_index 和 g_buffer_full：

They are shared between the interrupt context and the main loop.
Without volatile, the compiler might cache their values in registers and never reload them, so the main loop could miss the updates from the interrupt.
volatile tells the compiler to always read the actual memory location.

Q6. 如果老师让你“改成 512 点 FFT，采样率 2 kHz”，你会改哪里？

答法要有条理：

Change #define FFT_SIZE 1024 to 512.

Adjust SAMPLE_RATE_HZ to 2000.0f.

Make sure all arrays depending on FFT_SIZE use the new size.

Reconfigure TIM6 so that its interrupt frequency becomes 2 kHz.

Then the rest of the FFT code still works, but the frequency resolution Fs / N will change.

6. 接下来怎么用这份代码复习？

建议你做三件事：

手写一个“缩小版主流程”
把：

全局变量定义（FFT_SIZE, buffer, volatile 标志）

main 里 init + HAL_TIM_Base_Start_IT

while(1) {}; 里 if (g_buffer_full) { FFT + peak }

TIM 回调里采样
写成一个简化版 C 代码，只保留关键行，配你喜欢的英文注释。

对着真正 main.c，录一遍“讲解版本”：
从“采样是怎么来的”讲到“FFT 怎么算、频率怎么来的、速度怎么来的”。

把我上面 Q1–Q6 按你自己的话背一遍，能脱稿回答就差不多了。
