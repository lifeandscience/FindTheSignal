
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

// DIRECTIONS
#define NODIR  0
#define LEFT   2
#define UP     3
#define RIGHT  4
#define DOWN   5

// STATES
#define USER        10
#define WANDERING   11
#define HIGHER      12
#define LOWER       13
#define LEFTWARD    14
#define RIGHTWARD   15
#define HOLDING     16


int currentState;
int currentDir  = NODIR;
int timeout     = 10;
int holdtimeout = 12;
int clock       = 0;
int drift       = 0;
int wander      = 0;

int sensorIndex = 0;
long sensorValue[10];

long audioThreshold, currentAudio, previousAudio;
long checkAudio();


int check();
int newState(int current);
void report(int s);


/*
 * Load up the baseline Audio input data
 */

void setup()
{
   pinMode(13,OUTPUT);
   Serial.begin(115200);
   for (int i=2; i<6; i++) 
   {
	pinMode(i, INPUT);
	digitalWrite(i,HIGH);
   }
   for (int i=0; i<10; i++) 
   {
	sensorValue[i] = analogRead(A0);
	delay(100);
   }
   currentState = USER;
   audioThreshold  = 50;
   currentAudio = previousAudio = 0;
}


int check()
{
int status = 1;

	if ( currentDir != NODIR )
	{
		pinMode(currentDir, INPUT);
		digitalWrite(currentDir, HIGH);
	}

//        Serial.print(digitalRead(2));
//        Serial.print(digitalRead(3));
//        Serial.print(digitalRead(4));
//        Serial.println(digitalRead(5));

	if (    digitalRead(2) == 0
	     ||	digitalRead(3) == 0
	     ||	digitalRead(4) == 0
	     ||	digitalRead(5) == 0 ) status = 0;

	if (currentDir != NODIR)
	{
		pinMode(currentDir, OUTPUT);
		digitalWrite(currentDir, LOW);
	}
	return status;
}

void sampleAnalog()
{
	if (sensorIndex < 10)
		sensorValue[sensorIndex++] = analogRead(A0);
	else
		sensorIndex = 0;
}		

/*
 * If we detect audio (standard deviation of analog input)
 * we will halt the seeking and listen to the audio.
 */

long checkAudio()
{
   int average = 0;
   for (int i=0; i<10; i++)
	average += sensorValue[i];
   average = average/10;

   long deviation;
   deviation = 0;
   for (int i=0; i<10; i++)
   {
	deviation += (sensorValue[i]-average)*(sensorValue[i]-average);
   }
   if (deviation > 100) 
   { Serial.print("("); Serial.print(deviation); Serial.print(")"); }
   return deviation;
}

void loop()
{
	delay(500);
	clock++;                                 // CLOCK TICK

	sampleAnalog();                          // Sample Audio Activity

	if ( (clock % 10) == 0 )                // Compute deviation
		currentAudio = checkAudio();

	currentState = newState(currentState);
	report(currentState);

	if (currentState == WANDERING)          // Occasionally
	{                                       // change direction
		if (drift++ > 6)
		{
			move(random(2,6));
			drift = 0;
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
	Serial.print(currentDir);Serial.print(" ");
}

void stop()         
{
	if (currentDir != NODIR)
	{
		pinMode(currentDir, INPUT);
		digitalWrite(currentDir, HIGH);
	}
	currentDir = NODIR; 
}

void nudge(int dir)
{
	move(dir);
	delay(100);
	stop();
}
	
void flash()
{
	digitalWrite(13,HIGH);
	delay(800);
	digitalWrite(13,LOW);
}


// STATE: user, wandering, higher, lower, left, right, holding 

int newState(int current)
{
	if ( check() == 0 )        // Check for User Input
	{
		timeout = 10;   // Reset max timeout value (ms)
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
		Serial.println(timeout);
		return USER;
	}
	else if ( current == WANDERING )
	{
		if (   wander > 8 )
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
                 && wander > 8
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
			holdtimeout = 12;
			return HOLDING;
		}
	}
	else if (current == HOLDING)
	{
		if (holdtimeout > 0) holdtimeout--;
		if (holdtimeout == 0)
		{
			drift = 0;
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

