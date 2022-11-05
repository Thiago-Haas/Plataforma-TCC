#include <FreeRTOS.h>
#include <task.h>
#include <queue.h>
#include <harvsoc.h>

#include <stdio.h>

#include "riscv-virt.h"


/* Set to 1 to use direct mode and set to 0 to use vectored mode.
VECTOR MODE=Direct --> all traps into machine mode cause the pc to be set to the
vector base address (BASE) in the mtvec register.
VECTOR MODE=Vectored --> all synchronous exceptions into machine mode cause the
pc to be set to the BASE, whereas interrupts cause the pc to be set to the
address BASE plus four times the interrupt cause number.
*/
#define mainVECTOR_MODE_DIRECT 1

#if mainVECTOR_MODE_DIRECT == 1
	extern void freertos_risc_v_trap_handler(void);
#else
	extern void freertos_vector_table(void);
#endif

void vApplicationMallocFailedHook( void );
void vApplicationIdleHook( void );
void vApplicationStackOverflowHook( TaskHandle_t pxTask, char *pcTaskName );
void vApplicationTickHook( void );

/*-----------------------------------------------------------*/

void vApplicationMallocFailedHook( void ) {
	/* vApplicationMallocFailedHook() will only be called if
	configUSE_MALLOC_FAILED_HOOK is set to 1 in FreeRTOSConfig.h.  It is a hook
	function that will get called if a call to pvPortMalloc() fails.ript fro
	pvPortMalloc() is called internally by the kernel whenever a task, queue,
	timer or semaphore is created.  It is also called by various parts of the
	demo application.  If heap_1.c or heap_2.c are used, then the size of the
	heap available to pvPortMalloc() is defined by configTOTAL_HEAP_SIZE in
	FreeRTOSConfig.h, and the xPortGetFreeHeapSize() API function can be used
	to query the size of free heap space that remains (although it does not
	provide information on how the remaining heap might be fragmented). */
	taskDISABLE_INTERRUPTS();
	for( ;; );
}
/*-----------------------------------------------------------*/

void vApplicationIdleHook( void ) {
	/* vApplicationIdleHook() will only be called if configUSE_IDLE_HOOK is set
	to 1 in FreeRTOSConfig.h.  It will be called on each iteration of the idle
	task.  It is essential that code added to this hook function never attempts
	to block in any way (for example, call xQueueReceive() with a block time
	specified, or call vTaskDelay()).  If the application makes use of the
	vTaskDelete() API function (as this demo application does) then it is also
	important that vApplicationIdleHook() is permitted to return to its calling
	function, because it is the responsibility of the idle task to clean up
	memory allocated by the kernel to any task that has since been deleted. */
}
/*-----------------------------------------------------------*/

void vApplicationStackOverflowHook( TaskHandle_t pxTask, char *pcTaskName ) {
	( void ) pcTaskName;
	( void ) pxTask;

	/* Run time stack overflow checking is performed if
	configCHECK_FOR_STACK_OVERFLOW is defined to 1 or 2.  This hook
	function is called if a stack overflow is detected. */
	taskDISABLE_INTERRUPTS();
	for( ;; );
}
/*-----------------------------------------------------------*/

void vApplicationTickHook( void ) {}
/*-----------------------------------------------------------*/

void vAssertCalled( void ) {
	volatile uint32_t ulSetTo1ToExitFunction = 0;

	taskDISABLE_INTERRUPTS();
	while( ulSetTo1ToExitFunction != 1 ) {
		__asm volatile( "NOP" );
	}
}

static void prvSetupHardware( void ) {
#if mainVECTOR_MODE_DIRECT == 1
	__asm__ volatile( "csrw mtvec, %0" :: "r"( freertos_risc_v_trap_handler ) );
#else
	#error "Not yet supported.."
	__asm__ volatile( "csrw mtvec, %0" :: "r"( ( uintptr_t )freertos_vector_table | 0x1 ) );
#endif
}


/* Priorities used by the tasks. */
#define mainQUEUE_RECEIVE_TASK_PRIORITY		( tskIDLE_PRIORITY + 2 )
#define	mainQUEUE_SEND_TASK_PRIORITY		( tskIDLE_PRIORITY + 1 )

/* The rate at which data is sent to the queue.  The 200ms value is converted
to ticks using the pdMS_TO_TICKS() macro. */
#ifndef IS_SIMULATION
#define mainQUEUE_SEND_FREQUENCY_MS			pdMS_TO_TICKS( 500 )
#else
#define mainQUEUE_SEND_FREQUENCY_MS			pdMS_TO_TICKS( 50 )
#endif

/* The maximum number items the queue can hold.  The priority of the receiving
task is above the priority of the sending task, so the receiving task will
preempt the sending task and remove the queue items each time the sending task
writes to the queue.  Therefore the queue will never have more than one item in
it at any time, and even with a queue length of 1, the sending task will never
find the queue full. */
#define mainQUEUE_LENGTH					( 1 )

/*-----------------------------------------------------------*/

/* The queue used by both tasks. */
static QueueHandle_t xQueue = NULL;

/*-----------------------------------------------------------*/

static void prvQueueSendTask( void *pvParameters ) {
	TickType_t xNextWakeTime;
	const unsigned long ulValueToSend = 100UL;
	const char * const pcMessage1 = "Transfer1";
	const char * const pcMessage2 = "Transfer2";
	int f = 1;

	/* Remove compiler warning about unused parameter. */
	( void ) pvParameters;

	/* Initialise xNextWakeTime - this only needs to be done once. */
	xNextWakeTime = xTaskGetTickCount();

	for( ;; ) {
		char buf[40];

		sprintf( buf, "%d: %s: %s", xGetCoreID(),
				pcTaskGetName( xTaskGetCurrentTaskHandle() ),
				( f ) ? pcMessage1 : pcMessage2 );
		vSendString( buf );
		f = !f;

		/* Place this task in the blocked state until it is time to run again. */
		vTaskDelayUntil( &xNextWakeTime, mainQUEUE_SEND_FREQUENCY_MS );

		/* Send to the queue - causing the queue receive task to unblock and
		toggle the LED.  0 is used as the block time so the sending operation
		will not block - it shouldn't need to block as the queue should always
		be empty at this point in the code. */
		xQueueSend( xQueue, &ulValueToSend, 0U );
	}
}

/*-----------------------------------------------------------*/

static void prvQueueReceiveTask( void *pvParameters ) {
	unsigned long ulReceivedValue;
	const unsigned long ulExpectedValue = 100UL;
	const char * const pcMessage1 = "Blink1";
	const char * const pcMessage2 = "Blink2";
	const char * const pcFailMessage = "Unexpected value received\r\n";
	int f = 1;

	/* Remove compiler warning about unused parameter. */
	( void ) pvParameters;

	for( ;; ) {
		char buf[40];

		/* Wait until something arrives in the queue - this task will block
		indefinitely provided INCLUDE_vTaskSuspend is set to 1 in
		FreeRTOSConfig.h. */
		xQueueReceive( xQueue, &ulReceivedValue, portMAX_DELAY );

		/*  To get here something must have been received from the queue, but
		is it the expected value?  If it is, toggle the LED. */
		if( ulReceivedValue == ulExpectedValue ) {
			sprintf( buf, "%d: %s: %s", xGetCoreID(),
					pcTaskGetName( xTaskGetCurrentTaskHandle() ),
					( f ) ? pcMessage1 : pcMessage2 );
			vSendString( buf );
			f = !f;

			ulReceivedValue = 0U;
		} else {
			vSendString( pcFailMessage );
		}
#ifdef IS_SIMULATION
		// stop simulation when message is received
		vSendString("halt-sim");
#endif
	}
}

static void IdleTask(void* pvParameters) {
  while(1) {
	wdt_feed();
	vTaskDelay(pdMS_TO_TICKS(100));
  }
}

/*-----------------------------------------------------------*/

int main( void ) {
  prvSetupHardware();
	vSendString( "Hello FreeRTOS!" );

	/* Create the queue. */
	xQueue = xQueueCreate( mainQUEUE_LENGTH, sizeof( uint32_t ) );

	if( xQueue != NULL ) {
		/* Start the two tasks as described in the comments at the top of this
		file. */
		xTaskCreate( prvQueueReceiveTask, "Rx", configMINIMAL_STACK_SIZE * 2U, NULL,
					mainQUEUE_RECEIVE_TASK_PRIORITY, NULL );
		xTaskCreate( prvQueueSendTask, "Tx", configMINIMAL_STACK_SIZE * 2U, NULL,
					mainQUEUE_SEND_TASK_PRIORITY, NULL );
	}

  xTaskCreate(IdleTask, "IdleTask", 512, NULL, 0, NULL);

	vSendString("Tasks created");

	vTaskStartScheduler();

	return 0;
}
