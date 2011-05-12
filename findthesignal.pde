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
 * has expired. The Arduino will set the flag "controlling",
 * switch the four pins to outputs, and set the seeker in motion.
 *
 * May 12, 2011
 * Peter Reintjes
 * (C) 2011 Museum of Life and Science 2011
 * 
 */

int pattern     = 1;
int controlling = 0;
int timeout     = 20000;
int clock       = 0;

int sensorIndex = 0;
int sensorValue[10];

/*
 * Load up the baseline Audio input data
 */

void setup() {
   for (int i=0; i<10; i++) 
   {
	sensorValue[i] = analogRead(A0);
	delay(100);
   }
}


/*
 * "controlling" is 1 when this program is controlling
 * the satellite seeker, 0 when the user is moving the
 * joystick.
 */

int check()
{
int status = 1;
	if (controlling) /* Set inputs with pullups */
	{
		pinMode(2,INPUT); digitalWrite(2,HIGH);
		pinMode(3,INPUT); digitalWrite(3,HIGH);
		pinMode(4,INPUT); digitalWrite(4,HIGH);
		pinMode(5,INPUT); digitalWrite(5,HIGH);
	}

	if (   digitalRead(2) == 0   /* Joystick is Active */
            || digitalRead(3) == 0 
            || digitalRead(4) == 0 
            || digitalRead(5) == 0 )
	{
		status = 0;
	}

	if (controlling)
	{
		pinMode(2,OUTPUT);
		pinMode(3,OUTPUT);
		pinMode(4,OUTPUT);
		pinMode(5,OUTPUT);
	}
	return status;
}


int nextMove(int current)
{
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

void checkAnalog()
{
   int i, average, deviation;
   average = 0;
   for (int i=0; i<10; i++)
	average += sensorValue[i];
   average = average/10;
   deviation = 0;
   for (int i=0; i<10; i++)
	deviation += (sensorValue[i]-average)*(sensorValue[i]-average);

   if (deviation > 50)
   {
	timeout = 20000;
   }
}

void loop() {
	if (check() == 0)   /* Check for User Input  */
	{
		controlling = 0;
		timeout = 20000;   /* Reset max timeout value (ms)*/
	}
	else
	{
		if (controlling == 0)
			Serial.println("We are now in control");
		controlling = 1;
	}
/*
 * If we are controlling things, we will change the
 * pattern every so often  ( (clock % N) == 0 )
 */

	if ( controlling && ((clock % 100) == 0) )
	{
		pattern  = 1<<(int)(rand()*4);
		Serial.println(pattern);
		if ( pattern & 1 ) digitalWrite(2,LOW);
		if ( pattern & 2 ) digitalWrite(3,LOW);
		if ( pattern & 4 ) digitalWrite(4,LOW);
		if ( pattern & 8 ) digitalWrite(5,LOW);
	}
	clock++;                          /* TICK CLOCK */
	if (timeout > 0 ) timeout -= 200; /* Decrement TIMEOUT */
	sampleAnalog();                   /* Sample Audio Activity */
}






