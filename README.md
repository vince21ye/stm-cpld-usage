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
