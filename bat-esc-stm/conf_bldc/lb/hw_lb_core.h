/*
	Copyright 2016 - 2022 Benjamin Vedder	benjamin@vedder.se

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * TODO:
 * * MOSFET: https://www.digikey.se/en/products/detail/toshiba-semiconductor-and-storage/TPH1R306P1-L1Q/10447088
 */

#ifndef HW_LB_CORE_H_
#define HW_LB_CORE_H_

#ifndef HW_HAS_DUAL_PARALLEL
#define HW_HAS_DUAL_MOTORS
#endif

#define HW_SET_SINGLE_MOTOR()	hw_configure_single_motor()

#ifdef HW_HAS_DUAL_PARALLEL
#ifdef HW_VER_0
#define HW_NAME                 "LB_PARALLEL"
#endif
#else
#ifdef HW_VER_0
#define HW_NAME                 "bat-esc-stm"
#endif
#endif

#define HW_DEFAULT_ID			10

#ifndef HW_NAME
#error "Must define hardware type"
#endif

#define HW_DEAD_TIME_NSEC               1000.0
#define HW_HAS_3_SHUNTS
#define HW_HAS_PHASE_SHUNTS

// Note: We have DG9421, which is normally closed
#define HW_HAS_PHASE_FILTERS
#define PHASE_FILTER_GPIO               GPIOE
#define PHASE_FILTER_PIN                15
#define PHASE_FILTER_GPIO_M2            GPIOE
#define PHASE_FILTER_PIN_M2             1
#define PHASE_FILTER_ON()               palClearPad(PHASE_FILTER_GPIO, PHASE_FILTER_PIN)
#define PHASE_FILTER_OFF()              palSetPad(PHASE_FILTER_GPIO, PHASE_FILTER_PIN)
#define PHASE_FILTER_ON_M2()            palClearPad(PHASE_FILTER_GPIO_M2, PHASE_FILTER_PIN_M2)
#define PHASE_FILTER_OFF_M2()           palSetPad(PHASE_FILTER_GPIO_M2, PHASE_FILTER_PIN_M2)

#define CURRENT_FILTER_GPIO				GPIOE
#define CURRENT_FILTER_PIN				3
#define CURRENT_FILTER_ON()				palClearPad(CURRENT_FILTER_GPIO, CURRENT_FILTER_PIN)
#define CURRENT_FILTER_OFF()			palSetPad(CURRENT_FILTER_GPIO, CURRENT_FILTER_PIN)
#define CURRENT_FILTER_GPIO_M2			GPIOE
#define CURRENT_FILTER_PIN_M2			0
#define CURRENT_FILTER_ON_M2()			palClearPad(CURRENT_FILTER_GPIO, CURRENT_FILTER_PIN)
#define CURRENT_FILTER_OFF_M2()			palSetPad(CURRENT_FILTER_GPIO, CURRENT_FILTER_PIN)

#define DCCAL_ON()
#define DCCAL_OFF()

// Macros
#define ENABLE_GATE()
#define DISABLE_GATE()

#define ADC_SW_EN_PORT				GPIOB
#define ADC_SW_EN_PIN				12
#define ADC_SW_1_PORT				GPIOD
#define ADC_SW_1_PIN				7
#define ADC_SW_2_PORT				GPIOB
#define ADC_SW_2_PIN				3
#define ADC_SW_3_PORT				GPIOE
#define ADC_SW_3_PIN				7

#define AD_DIS()					palClearPad(ADC_SW_EN_PORT, ADC_SW_EN_PIN)
#define AD1_L()						palClearPad(ADC_SW_1_PORT, ADC_SW_1_PIN)
#define AD1_H()						palSetPad(ADC_SW_1_PORT, ADC_SW_1_PIN)
#define AD2_L()						palClearPad(ADC_SW_2_PORT, ADC_SW_2_PIN)
#define AD2_H()						palSetPad(ADC_SW_2_PORT, ADC_SW_2_PIN)
#define AD3_L()						palClearPad(ADC_SW_3_PORT, ADC_SW_3_PIN)
#define AD3_H()						palSetPad(ADC_SW_3_PORT, ADC_SW_3_PIN)
#define AD_EN()						palSetPad(ADC_SW_EN_PORT, ADC_SW_EN_PIN)

#define ENABLE_MOS_TEMP1()			AD_DIS();	AD3_L();	AD2_L();	AD1_L();	AD_EN();
#define ENABLE_MOS_TEMP2()			AD_DIS();	AD3_L();	AD2_L();	AD1_H();	AD_EN();
#define ENABLE_MOS_TEMP3()			AD_DIS();	AD3_L();	AD2_H();	AD1_L();	AD_EN();
#define ENABLE_MOS2_TEMP1()			AD_DIS();	AD3_L();	AD2_H();	AD1_H();	AD_EN();
#define ENABLE_MOS2_TEMP2()			AD_DIS();	AD3_H();	AD2_L();	AD1_L();	AD_EN();
#define ENABLE_MOS2_TEMP3()			AD_DIS();	AD3_H();	AD2_L();	AD1_H();	AD_EN();

#define IS_DRV_FAULT()				0
#define IS_DRV_FAULT2()				0

#define LED_GREEN_ON()				palSetPad(GPIOB, 5);
#define LED_GREEN_OFF()				palClearPad(GPIOB, 5);
#define LED_RED_ON()				palSetPad(GPIOB, 6);
#define LED_RED_OFF()				palClearPad(GPIOB, 6);

/*
 * ADC Vector
 *
 * 0:  IN0    CURR3
 * 1:  IN15    CURR4
 * 2:  IN3     SERVO2/ADC
 * 3:   IN9     CURR1
 * 4:   IN8     CURR2
 * 5:   IN10    AN_IN
 * 6:   IN0     SENS2
 * 7:   IN1     SENS3
 * 8:   IN2     SENS1
 * 9:   IN5     ADC_EXT
 * 10:   IN4     ADC_TEMP
 * 11:   IN13    SENS4
 * 12:   Vrefint
 * 13:   IN11    SENS6
 * 14:  IN12    SENS5
 * 15:  IN6     ADC_EXT2
 */

#define HW_ADC_CHANNELS			15
#define HW_ADC_CHANNELS_EXTRA	15
#define HW_ADC_INJ_CHANNELS		2
#define HW_ADC_NBR_CONV			5

// ADC Indexes

#define ADC_IND_CURR1			0
#define ADC_IND_CURR2			1
#define ADC_IND_VIN_SENS		2

#define ADC_IND_CURR3			3
#define ADC_IND_CURR4			4
#define ADC_IND_EXT				5

#define ADC_IND_CURR6			6
#define ADC_IND_CURR5			7
#define ADC_IND_SENS4			8

#define ADC_IND_ADC_MUX			9
#define ADC_IND_SENS5			10
#define ADC_IND_SENS6			11

#define ADC_IND_SENS2			12
#define ADC_IND_SENS3			13
#define ADC_IND_SENS1			14

#define ADC_IND_TEMP_MOS		15
#define ADC_IND_TEMP_MOS_2		16
#define ADC_IND_TEMP_MOS_3		17
#define ADC_IND_TEMP_MOS_M2		18
#define ADC_IND_TEMP_MOS_2_M2	19
#define ADC_IND_TEMP_MOS_3_M2	20

#define ADC_IND_TEMP_MOTOR		21
#define ADC_IND_TEMP_MOTOR_2	22

#define HW_GET_INJ_CURR1()		ADC_GetInjectedConversionValue(ADC1, ADC_InjectedChannel_1)
#define HW_GET_INJ_CURR2()		ADC_GetInjectedConversionValue(ADC2, ADC_InjectedChannel_1)
#define HW_GET_INJ_CURR3()		ADC_GetInjectedConversionValue(ADC1, ADC_InjectedChannel_2)

// ADC macros and settings

// Component parameters (can be overridden)
#ifndef V_REG
#define V_REG					3.3
#endif
#ifndef VIN_R1
#define VIN_R1					39000.0
#endif
#ifndef VIN_R2
#define VIN_R2					2200.0
#endif

#ifndef CURRENT_AMP_GAIN
#define CURRENT_AMP_GAIN        50.0
#endif
#ifndef CURRENT_SHUNT_RES
#define CURRENT_SHUNT_RES       0.00005
#endif

// Input voltage
#define GET_INPUT_VOLTAGE()		((V_REG / 4095.0) * (float)ADC_Value[ADC_IND_VIN_SENS] * ((VIN_R1 + VIN_R2) / VIN_R2))

// Voltage on ADC channel
#define ADC_VOLTS(ch)			((float)ADC_Value[ch] / 4095.0 * V_REG)

// NTC Termistors
#define NTC_RES(adc_val)		(10000.0 / ((4095.0 / (float)adc_val) - 1.0)) // Motor temp sensor on low side // High side ->((4095.0 * 10000.0) / adc_val - 10000.0)
#define NTC_TEMP(adc_ind)		hw_get_temp(adc_ind)

#define NTC_RES_MOTOR(adc_val)	(10000.0 / ((4095.0 / (float)adc_val) - 1.0)) // Motor temp sensor on low side
#define NTC_TEMP_MOTOR(beta)	hw_get_temp_motor(2)
#define NTC_TEMP_MOTOR_2(beta)	hw_get_temp_motor(1)

#define NTC_TEMP_MOS1()			(1.0 / ((logf(NTC_RES(ADC_Value[ADC_IND_TEMP_MOS]) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15)
#define NTC_TEMP_MOS2()			(1.0 / ((logf(NTC_RES(ADC_Value[ADC_IND_TEMP_MOS_2]) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15)
#define NTC_TEMP_MOS3()			(1.0 / ((logf(NTC_RES(ADC_Value[ADC_IND_TEMP_MOS_3]) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15)
#define NTC_TEMP_MOS1_M2()		(1.0 / ((logf(NTC_RES(ADC_Value[ADC_IND_TEMP_MOS_M2]) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15)
#define NTC_TEMP_MOS2_M2()		(1.0 / ((logf(NTC_RES(ADC_Value[ADC_IND_TEMP_MOS_2_M2]) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15)
#define NTC_TEMP_MOS3_M2()		(1.0 / ((logf(NTC_RES(ADC_Value[ADC_IND_TEMP_MOS_3_M2]) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15)

// UART Peripheral
#define HW_UART_DEV				SD3
#define HW_UART_GPIO_AF			GPIO_AF_USART3
#define HW_UART_TX_PORT			GPIOB
#define HW_UART_TX_PIN			10
#define HW_UART_RX_PORT			GPIOB
#define HW_UART_RX_PIN			11

// ICU Peripheral for servo decoding
#define HW_ICU_TIMER			TIM9
#define HW_ICU_TIM_CLK_EN()		RCC_APB2PeriphClockCmd(RCC_APB2Periph_TIM9, ENABLE)
#define HW_ICU_DEV				ICUD9
#define HW_ICU_CHANNEL			ICU_CHANNEL_1
#define HW_ICU_GPIO_AF			GPIO_AF_TIM9
#define HW_ICU_GPIO				GPIOE
#define HW_ICU_PIN				5

// I2C Peripheral
#define HW_I2C_DEV				I2CD2
#define HW_I2C_GPIO_AF			GPIO_AF_I2C2
#define HW_I2C_SCL_PORT			GPIOB
#define HW_I2C_SCL_PIN			10
#define HW_I2C_SDA_PORT			GPIOB
#define HW_I2C_SDA_PIN			11

// Hall/encoder pins
#define HW_HALL_ENC_GPIO1		GPIOD
#define HW_HALL_ENC_PIN1		13
#define HW_HALL_ENC_GPIO2		GPIOD
#define HW_HALL_ENC_PIN2		12
#define HW_HALL_ENC_GPIO3		GPIOD
#define HW_HALL_ENC_PIN3		14
#define HW_ENC_TIM				TIM4
#define HW_ENC_TIM_AF			GPIO_AF_TIM4
#define HW_ENC_TIM_CLK_EN()		RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM4, ENABLE)
#define HW_ENC_EXTI_PORTSRC		EXTI_PortSourceGPIOD
#define HW_ENC_EXTI_PINSRC		EXTI_PinSource14
#define HW_ENC_EXTI_CH			EXTI15_10_IRQn
#define HW_ENC_EXTI_LINE		EXTI_Line14
#define HW_ENC_EXTI_ISR_VEC		EXTI15_10_IRQHandler
#define HW_ENC_TIM_ISR_CH		TIM4_IRQn
#define HW_ENC_TIM_ISR_VEC		TIM4_IRQHandler

#define HW_HALL_ENC_GPIO4		GPIOB
#define HW_HALL_ENC_PIN4		4
#define HW_HALL_ENC_GPIO5		GPIOB
#define HW_HALL_ENC_PIN5		2
#define HW_HALL_ENC_GPIO6		GPIOB
#define HW_HALL_ENC_PIN6		7
#define HW_ENC_TIM2				TIM3
#define HW_ENC_TIM_AF2			GPIO_AF_TIM3
#define HW_ENC_TIM_CLK_EN2()	RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM3, ENABLE)
#define HW_ENC_EXTI_PORTSRC2	EXTI_PortSourceGPIOB
#define HW_ENC_EXTI_PINSRC2		EXTI_PinSource7
#define HW_ENC_EXTI_CH2			EXTI9_5_IRQn
#define HW_ENC_EXTI_LINE2		EXTI_Line6
#define HW_ENC_EXTI_ISR_VEC2	EXTI9_5_IRQHandler
#define HW_ENC_TIM_ISR_CH2		TIM3_IRQn
#define HW_ENC_TIM_ISR_VEC2		TIM3_IRQHandler

// SPI pins
#define HW_SPI_DEV				SPID1
#define HW_SPI_GPIO_AF			GPIO_AF_SPI1
#define HW_SPI_PORT_NSS			GPIOB
#define HW_SPI_PIN_NSS			11
#define HW_SPI_PORT_SCK			GPIOA
#define HW_SPI_PIN_SCK			8
#define HW_SPI_PORT_MOSI		GPIOA
#define HW_SPI_PIN_MOSI			15
#define HW_SPI_PORT_MISO		GPIOA
#define HW_SPI_PIN_MISO			9

// LSM6DS3
#define LSM6DS3_SDA_GPIO		GPIOB
#define LSM6DS3_SDA_PIN			9
#define LSM6DS3_SCL_GPIO		GPIOB
#define LSM6DS3_SCL_PIN			8
#define IMU_ROT_90

// Measurement macros
#define ADC_V_L1				ADC_Value[ADC_IND_SENS1]
#define ADC_V_L2				ADC_Value[ADC_IND_SENS2]
#define ADC_V_L3				ADC_Value[ADC_IND_SENS3]
#define ADC_V_L4				ADC_Value[ADC_IND_SENS4]
#define ADC_V_L5				ADC_Value[ADC_IND_SENS5]
#define ADC_V_L6				ADC_Value[ADC_IND_SENS6]
#define ADC_V_ZERO				(ADC_Value[ADC_IND_VIN_SENS] / 2)

// Macros
#define READ_HALL1()			palReadPad(HW_HALL_ENC_GPIO1, HW_HALL_ENC_PIN1)
#define READ_HALL2()			palReadPad(HW_HALL_ENC_GPIO2, HW_HALL_ENC_PIN2)
#define READ_HALL3()			palReadPad(HW_HALL_ENC_GPIO3, HW_HALL_ENC_PIN3)

#define READ_HALL1_2()			palReadPad(HW_HALL_ENC_GPIO4, HW_HALL_ENC_PIN4)
#define READ_HALL2_2()			palReadPad(HW_HALL_ENC_GPIO5, HW_HALL_ENC_PIN5)
#define READ_HALL3_2()			palReadPad(HW_HALL_ENC_GPIO6, HW_HALL_ENC_PIN6)

//CAN
#define HW_CANRX_PORT			GPIOD
#define HW_CANRX_PIN			0
#define HW_CANTX_PORT			GPIOD
#define HW_CANTX_PIN			1

#ifndef MCCONF_L_MAX_VOLTAGE
#define MCCONF_L_MAX_VOLTAGE		55.0
#endif

// Setting limits
#ifdef HW_HAS_DUAL_PARALLEL
#define HW_LIM_CURRENT					-500.0, 500.0
#define HW_LIM_CURRENT_ABS				0.0, 700.0
#define MCCONF_L_MAX_ABS_CURRENT		600.0
#define MCCONF_FOC_OFFSETS_CURRENT_0	4096.0
#define MCCONF_FOC_OFFSETS_CURRENT_1	4096.0
#define MCCONF_FOC_OFFSETS_CURRENT_2	4096.0
#else
#define HW_LIM_CURRENT					-320.0, 320.0
#define HW_LIM_CURRENT_ABS				0.0, 500.0
#define MCCONF_L_MAX_ABS_CURRENT		350.0
#endif

#define HW_LIM_CURRENT_IN				-250.0, 250.0
#define HW_LIM_VIN						6.0, 57.0
#define HW_LIM_ERPM						-200e3, 200e3

// Functions
float hw_get_temp(int ad);
float hw_get_temp_motor(int motor);
void hw_clear_can_fault(void);
void hw_configure_single_motor(void);

#endif /* HW_LB_CORE_H_ */
