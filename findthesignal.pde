
/*
 * When the Find-the-Signal exhibit is unattended
 * for more than 20 seconds, this program will cause
 * the satellite seeker to wander about, more or less
 * at random.
 *
 * The four control wires connecting the joystick to the
 * motor controls (Left, Right, Up, Down) are checked 
 * several times a second by placing the Arduino pins in
 * input mode and seeing if any of them are grounded.
 *
 * If none of the four inputs are grounded, the Arduino
 * will start a 20-second clock.
 *
 * If one or more are at 0v, the Arduino will clear the
 * 20-second clock and continue checking, but do nothing else.
 *
 * If none of the four inputs are grounded and the 20-second
 * has expired, we will go into "wandering" mode.
 *
 * May 12, 2011
 * Peter Reintjes
 * (C) 2011 Museum of Life and Science 2011
 * 
 */

// DIRECTIONS (currentDir value = control pin number)

#define NODIR  0
#define LEFT   2
#define UP     3
#define RIGHT  4
#define DOWN   5

// currentDir value = control pin number

int currentDir  = NODIR;

#define LEFT_OUT     9
#define UP_OUT      10
#define RIGHT_OUT   11
#define LEFT_OUT    12

char *dirname[] = { "NODIR", "NODIR1","LEFT","UP","RIGHT","DOWN" };


// STATES
#define USER        10
#define WANDERING   11
#define HIGHER      12
#define LOWER       13
#define LEFTWARD    14
#define RIGHTWARD   15
#define HOLDING     16

#define MIN_WANDER_TIME     90
#define HOLD_TIME          240
#define CHANGE_DIRECTION    20

enum state { user, wandering, higher, lower, leftward, rightward, holding };
enum dir   { nodir = 0, left = 2, up = 3, right = 4, down = 5 };

int currentState;
int timeout     = HOLD_TIME;
int holdtimeout = HOLD_TIME;
int clock       = 0;
int drift       = CHANGE_DIRECTION;
int wander      = 0;

int sensorIndex = 0;
unsigned long sensorValue[10];

#define THRESHOLD  4000

long audioThreshold, currentAudio, previousAudio;
long checkAudio();


int checkJoystick();
int newState(int current);
void report(int s);


/*
 * Load up the baseline Audio input data
 */

void setup()
{
int i;
   pinMode(13,OUTPUT);
   Serial.begin(115200);
   for (i=2; i<6; i++) 
   {
	pinMode(i, INPUT);
	digitalWrite(i,LOW); // No pullup (high impedance?)
	pinMode(i+7, OUTPUT);
	digitalWrite(i+7,LOW);
   }

   for (i=0; i<10; delay(20),i++) sampleAnalog();

   currentState = USER;
   audioThreshold  = THRESHOLD;
   currentAudio = previousAudio = 0;
}


int checkJoystick()
{
int status = 1;

	if ( currentDir != NODIR )
	{
		pinMode(currentDir+7,OUTPUT);
		digitalWrite(currentDir+7,LOW);
	}

//        Serial.print(digitalRead(2));
//        Serial.print(digitalRead(3));
//        Serial.print(digitalRead(4));
//        Serial.println(digitalRead(5));

	if (    digitalRead(LEFT)  == 0
	     ||	digitalRead(UP)    == 0
	     ||	digitalRead(RIGHT) == 0
	     ||	digitalRead(DOWN)  == 0 ) status = 0;

	if (status == 1 && currentDir != NODIR)
	{
          // Output was on and there's no user input,
          // So turn it back on.
		pinMode(currentDir+7,INPUT);
		digitalWrite(currentDir+7,HIGH);
	}
	return status;
}

void sampleAnalog()
{
	if (sensorIndex > 9)
		 sensorIndex = 0;
	sensorValue[sensorIndex++] = analogRead(A0);
}		

/*
 * If we detect audio (large deviation of analog input)
 * we will halt the seeking and listen to the audio.
 */

long checkAudio()
{
   int i,average = 0;
   for (i=0; i<10; i++)
	average += sensorValue[i];
   average = average/10;

   long deviation;
   deviation = 0;
   for (i=0; i<10; i++)
   {
	deviation += (sensorValue[i]-average)*(sensorValue[i]-average);
   }

   if (deviation > THRESHOLD)
   {
	Serial.println("");
	for (i=0; i<10; i++)
	{
	 Serial.print("["); Serial.print(sensorValue[i]);Serial.print("]");
	}
	Serial.print("("); Serial.print(deviation); Serial.print(")");
   }

   return deviation;
}

void loop()
{
	clock++;                            // CLOCK TICK
	sampleAnalog();                     // Sample Audio Activity
	delay(100);

	if ( (clock % 10) == 0 )            // Compute deviation
		currentAudio = checkAudio();

	if ( (clock % 20) == 0) flashStatus();

	currentState = newState(currentState);
	report(currentState);

	if (currentState == WANDERING)          // Occasionally
	{                                       // change direction
		drift--;
		if (drift == 0)
		{
			move(random(2,6));
			drift = CHANGE_DIRECTION + 10*random(2,6);
		}
	}
}


// STATE: user, wandering, higher, lower, left, right, holding 

void move(int dir)
{
	stop();
	pinMode(dir, OUTPUT);
	digitalWrite(dir, LOW);
	currentDir = dir;
	Serial.print(dirname[currentDir]);Serial.print(" ");

}

void stop()         
{
	if (currentDir != NODIR)
	{
		pinMode(currentDir, INPUT);
		digitalWrite(currentDir, LOW);
	}
	currentDir = NODIR; 
}

void nudge(int dir)
{
	move(dir);
	delay(100);
	stop();
}
	
void flash1()
{
	digitalWrite(13,HIGH);
	delay(20);
	digitalWrite(13,LOW);
	delay(100);
}
void flashStatus()
{
int i = 0;
	if (currentDir == LEFT)  i = 1;
	if (currentDir == UP)    i = 2;
	if (currentDir == RIGHT) i = 3;
	if (currentDir == DOWN)  i = 4;

	while(i-- > 0) flash1();
}


// STATE: user, wandering, higher, lower, left, right, holding 

int newState(int current)
{
	if ( checkJoystick() == 0 )   // Check for User Input
	{
		timeout = HOLD_TIME;  // Reset max timeout value (ms)
		if (current != USER)
			Serial.println("User is taking over");
		current = USER;
	}

	if (current == USER)
	{
		if (timeout > 0) timeout--;
		if (timeout == 0)
		{
			Serial.println("We are now in control");
			wander = 0;
			currentAudio = previousAudio = 0;
			return WANDERING;
		}
//		Serial.println(timeout);
		return USER;
	}
	else if ( current == WANDERING )
	{
		if (   wander > MIN_WANDER_TIME )
		{
			wander = 0;
			if (currentAudio > audioThreshold )
			{
				previousAudio = currentAudio;
				return HIGHER;
			}
		}
		else
		{
			wander++;
		}
		return WANDERING;
	}
	else if (   current == WANDERING
                 && wander > MIN_WANDER_TIME
                 && currentAudio > audioThreshold )
	{
		previousAudio = currentAudio;
		return HIGHER;		
	}
	else if ( current == HIGHER )
	{
		nudge(UP);
		currentAudio = checkAudio();
		if (currentAudio > previousAudio)
		{
			previousAudio = currentAudio;
			return HIGHER;
		}
		else
		{
			nudge(DOWN);
			return LOWER;
		}
	}
	else if (current == LOWER)
	{
		nudge(DOWN);
		currentAudio = checkAudio();
		if (currentAudio > previousAudio)
		{
			previousAudio = currentAudio;
			return LOWER;
		}
		else
		{
			nudge(UP);
			return LEFTWARD;
		}
	}
	else if (current == LEFTWARD)
	{
		nudge(LEFT);
		currentAudio = checkAudio();
		if (currentAudio > previousAudio)
		{
			previousAudio = currentAudio;
			return LEFTWARD;
		}
		else
		{
			nudge(RIGHT);
			return RIGHTWARD;
		}
	}
	else if (current == RIGHTWARD)
	{
		nudge(RIGHT);
		currentAudio = checkAudio();
		if (currentAudio > previousAudio)
		{
			previousAudio = currentAudio;
			return RIGHTWARD;
		}
		else
		{
			nudge(LEFT);
			holdtimeout = HOLD_TIME;
			return HOLDING;
		}
	}
	else if (current == HOLDING)
	{
		if (holdtimeout > 0) holdtimeout--;
		if (holdtimeout == 0)
		{
			drift = 1;
			wander = 0;
			currentAudio = previousAudio = 0;
			return WANDERING;
		}
		return HOLDING;
	}
	Serial.print(current);
	Serial.println(" End of newState");
	return current;
}

static int lastState;

void report(int s)
{
	if (lastState == s) return;

	if (s == USER) Serial.println("USER");
	if (s == WANDERING) Serial.println("WANDERING");
	if (s == HIGHER) Serial.println("HIGHER");
	if (s == LOWER) Serial.println("LOWER");
	if (s == LEFTWARD) Serial.println("LEFTWARD");
	if (s == RIGHTWARD) Serial.println("RIGHTWARD");
	if (s == HOLDING) Serial.println("HOLDING");
	lastState = s;
}

