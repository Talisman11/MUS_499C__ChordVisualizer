/*
For my final project, I would like to continue using TouchOSC and SuperCollider, expanding on my TouchOSC project from two weeks ago. The main concept of that one was the ability to +/- 1 by a halfstep for each note, and the ability to toggle which and how many notes were stacked in a chord. I would like to incorporate visualizations in SuperCollider via a GUI, and potentially extend this to MIDI keyboard as well. Theoretically the MIDI keyboard component should not be too hard, but I do not have one of my own, so that might be a little cumbersome.

The final result would be a 3-system interface, using TouchOSC to toggle and play with the note/chord qualities (similar to the top part of most MIDI keyboards, but with unique functions that aren't your typical ADSR envelope or oscillator parameters), visualize it with SuperCollider on the computer (similar to my "Chordal Revolver" concept from last semester), and be able to use a MIDI device as input (worst comes to worst I will map my laptop keyboard to play with for the sake of demo-ing).
*/


/* TouchOSC:
 * Multifader - Pitch bend for each chromatic note
 * Multifader - ADSR
 * Rotary - LPF
 * Rotary - HPF
 * Fader - Gain
 */
(
MIDIClient.init;
MIDIIn.connectAll;
MIDIFunc.trace(false);
)


(
/* Global configuration variables */
~num_keys = 49;                   // number of keys on the MIDI keyboard
~root = 48;                       // Transpose up or down by octaves. ~root=60 would be C5 (standard), but 48 for C4 is one octave lower
~lowest_note = 36;                // Lowest src channel of MIDI notes
~intervals = (0..~num_keys);
~notes = ~root + ~intervals;
~pitch_bends = Array.newClear(12); // Unnecessary?
~synths = Array.newClear(~num_keys);
~adsr_keys = [\attackTime, \decayTime, \sustainLevel, \releaseTime];

/* Initial values for TouchOSC knobs/faders */
~bend = 0; ~hpf_c = 10; ~lpf_c = 10000;

/* Helper function that sets \key of all synths to specified val */
~update_synths = {
	arg key, val;

	(0..~num_keys-1).do({
		arg i;
		~synths[i].set(key, val);
	});
};

// TODO: Might need to move these init functions to somewhere in the code after the ~synths have been created
~init_mf_bend = {
	arg cell=1;

	OSCdef.new(
		\mf ++ cell, {
			arg msg;
			// ~pitch_bends[cell-1] = msg[1];

			// Update bend value for all octaves of the corresponding cell
			(cell-1, cell-1+12..~num_keys-1).do({
				arg i;
				~synths[i].set(\bend, msg[1]);
			});
		}, '/1/multifader1/' ++ cell
	);
};

/* Init ADSR function for all synths based on the input band (from TouchOSC) and its respective key */
~init_mf_adsr = {
	arg band=1, key=nil;

	OSCdef.new(
		\mf ++ band, {
			arg msg;

			(0..~num_keys-1).do({
				arg i;
				~synths[i].set(key, msg[1]);
			});
		}, '/1/multifader2/' ++ band);
};

/* Fire up the server */
s.waitForBoot({
	/* Define our synth */
	SynthDef.new(\simple, {
		arg note=60, amp=0.6, gate=0, phs=0, bend=0,
		    hpf_c=10, lpf_c=10000, hrq=1, lrq=1, width=0.5, multiply=1 // maybe use 'amp' instead?
		    attackTime=0.8, decayTime=1.0, sustainLevel=0.75, releaseTime=3;
		var freq, sig, env, filter, pan;


		freq = note.midicps * LFNoise1.kr(1!4).bipolar(0).midiratio * bend.midiratio;
		// sig = VarSaw.ar(freq, phs, MouseX.kr(0.01, 0.99), amp) * MouseY.kr(0.5, 0.8, 1);
		sig = VarSaw.ar(freq, phs, width, amp) * multiply;
		sig = sig.wrap(-1, 1);

		env = EnvGen.kr(Env.adsr(attackTime, decayTime, sustainLevel, releaseTime), gate);
		sig = env * sig;

		sig = RHPF.ar(sig, hpf_c, hrq);
		sig = RLPF.ar(sig, lpf_c, lrq);

		sig = Splay.ar(sig);
		Out.ar(0, sig);
	}).add;

	s.sync;

	/* Instantiate synths */
	(0..~num_keys-1).do({
		arg i;
		~synths[i] = Synth.new(\simple, [
			\note, ~notes[i],
			\hpf_c, ~hpf_c,
			\lpf_c, ~lpf_c
		]);
	});

	/* Init multifader OSCdefs */
	(0..11).do({
		arg i;

		~init_mf_bend.value(i);
	});

	(0..3).do({
		arg i;
		~init_mf_adsr.value(i, ~adsr_keys[i]);
	});
});

/* OSCdefs listening to TouchOSC inputs */
OSCdef.new(\master, {
	arg msg;
	var amp = msg[1];
	amp.postln;
	s.volume_(amp.explin(0.01, 1, -60, 6)); // in dB
}, '/1/fader1');

OSCdef.new(\lpf, {
	arg msg;
	var val = msg[1];

	~update_synths.value(\lpf_c, val.linexp(0, 1, 100, 2000));
}, '/1/rotary1');

OSCdef.new(\hpf, {
	arg msg;
	var val = msg[1];

	~update_synths.value(\hpf_c, val.linexp(0, 1, 2000, 10000));
}, '/1/rotary2');

// TODO: make sure this OSCdef picks up the right values, and maps them corrrectly into the synth update func
OSCdef.new(\xypad, {
	arg msg;
	var y = msg[0], x = msg[1];

	~update_synths.value(\width, x);
	~update_synths.value(\multiply, y);
}, '/1/xy1');

/* MIDIdefs listening to MIDI device */
MIDIdef.noteOn(\noteOn, {
	arg val, num, chan, src;
	[num, val].postln;
	~synths[num - ~lowest_note].set(\gate, 1);
});

MIDIdef.noteOff(\noteOff, {
	arg val, num, chan, src;
	~synths[num - ~lowest_note].set(\gate, 0);
});
)

( /* Exit gracefully */
OSCdef.freeAll;
MIDIdef.freeAll;
(0..~num_keys-1).do({
	arg i;
	~synths[i].free;
});
s.quit;
)