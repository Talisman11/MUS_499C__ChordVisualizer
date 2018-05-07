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
MIDIFunc.trace(true);
)

~touchOSC.disconnect
(
/* Global configuration variables */
~touchOSC = NetAddr.new("192.168.0.121", 9000);
~num_keys = 49;                   // number of keys on the MIDI keyboard
~root = 48;                       // Transpose up or down by octaves. ~root=60 would be C5 (standard), but 48 for C4 is one octave lower
~lowest_note = 36;                // Lowest src channel of MIDI notes
~intervals = (0..~num_keys);
~notes = ~root + ~intervals;
~synths = Array.newClear(~num_keys);
~adsr_keys = ["attackTime", "decayTime", "sustainLevel", "releaseTime"];

/* Initial values for TouchOSC knobs/faders */
~bend = 0; ~hpf_c = 10; ~lpf_c = 2000;

/* Helper function that sets \key of all synths to specified val */
~update_synths = {
	arg key, val;

	(0..~num_keys-1).do({
		arg i;
		~synths[i].set(key, val);
	});
};

~init_mf_bend = {
	arg cell=1;

	OSCdef.new(
		\mf ++ cell, {
			arg msg;

			// TODO: I suspect I need another multifader listener to handle the reset button
			msg.postln;

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

	OSCdef.new(\mf ++ band, {
		arg msg;
		var val = msg[1];

		if (key == "attackTime", {
			~update_synths.value(\attackTime, val.linexp(0, 1, 0.25, 1.5));
		});

		if (key == "decayTime", {
			~update_synths.value(\decayTime, val.linexp(0, 1, 0.75, 2));
		});

		if (key == "sustainLevel", {
			~update_synths.value(\sustainLevel, val.linexp(0, 1, 0.25, 1));
		});

		if (key == "releaseTime", {
			~update_synths.value(\attackTime, val.linexp(0, 1, 1, 5));
		});
	}, '/1/multifader2/' ++ band);
};

/* Fire up the server */
s.waitForBoot({
	/* Define our synth */
	SynthDef.new(\simple, {
		arg note=60, amp=0.6, gate=0, phs=0, bend=0,
		    hpf_c=10, lpf_c=10000, hrq=1, lrq=1, width=0.5, multiply=1, // maybe use 'amp' instead?
		    attackTime=0.8, decayTime=1.0, sustainLevel=0.75, releaseTime=3;
		var freq, sig, env, filter, pan;


		freq = note.midicps * LFNoise1.kr(1!4).bipolar(0.1).midiratio * bend.midiratio;
		// sig = VarSaw.ar(freq, phs, MouseX.kr(0.01, 0.99), amp).poll * MouseY.kr(0.5, 0.8, 1);
		sig = VarSaw.ar(freq, phs, width, amp) * multiply;
		sig = sig.wrap(-1, 1);

		env = EnvGen.kr(Env.adsr(attackTime, decayTime, sustainLevel, releaseTime), gate);
		sig = env * sig;

		sig = RHPF.ar(sig, hpf_c, hrq);
		sig = RLPF.ar(sig, lpf_c, lrq);

		sig = Splay.ar(sig);

		// So apparently I can only use a control rate to send signals when the gate is set to 1, since non-pos to positive.
		SendReply.kr(gate, '/gui', [note, bend]); // OSCdef in final_gui.scd file
		Out.ar(0, sig);
	}).add;

	s.sync;

	/* Turn on animations */
	u.animate_(true);

	/* Instantiate synths */
	(0..~num_keys-1).do({
		arg i;
		~synths[i] = Synth.new(\simple, [
			\note, ~notes[i],
			\hpf_c, ~hpf_c,
			\lpf_c, ~lpf_c
		]);
		~gui_note_array[i] = 0;
	});

	/* Init multifader OSCdefs */
	(0..11).do({
		arg i;

		~init_mf_bend.value(i);
	});

	(1..4).do({
		arg i;
		~init_mf_adsr.value(i, ~adsr_keys[i-1]);
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
	val.postln;
	~update_synths.value(\lpf_c, val.linexp(0, 1, 100, ~lpf_c));
}, '/1/rotary1');

OSCdef.new(\hpf, {
	arg msg;
	var val = msg[1];
	val.postln;

	~update_synths.value(\hpf_c, val.linexp(0, 1, ~hpf_c, 2000));
}, '/1/rotary2');

OSCdef.new(\xypad, {
	arg msg;
	var y = msg[1], x = msg[2];

	~update_synths.value(\width, x.linexp(0, 1, 0.01, 0.99));
	~update_synths.value(\multiply, y.linexp(0, 1, 0.5, 0.8));
}, '/1/xy1');

/* Reset button based off one of your replies to a comment in Tutorial 11 - https://www.youtube.com/watch?v=ZVTbRNu2BI0
 * But I think I did something wrong? Says:
 * 'SC_UdpInPort: received error - An existing connection was forcibly closed by the remote host'
 * */
OSCdef.new(\reset, {
	arg msg;
	msg.postln;

	~touchOSC.sendMsg(
		'/1/multifader1', // Send to multifader1, which is our pitch bend array
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	);
}, '/1/push1'); // Listening for push1 from TouchOSC


/* Temporarily use NanoKontrol CC's to simulate Keyboard */
MIDIdef.cc(\nano, {
	arg val, num, chan, src;
	var idx;

	num = ~lowest_note;
	~synths[num - ~lowest_note].set(\gate, 1);
}, 38);

MIDIdef.cc(\nano2, {
	arg val, num, chan, src;

	var idx;

	num = ~lowest_note;
	~synths[num - ~lowest_note].set(\gate, 0);
}, 54);

/* MIDIdefs listening to MIDI device */
MIDIdef.noteOn(\noteOn, {
	arg val, num, chan, src;

	~synths[num - ~lowest_note].set(\gate, 1);
});

MIDIdef.noteOff(\noteOff, {
	arg val, num, chan, src;

	~synths[num - ~lowest_note].set(\gate, 0);
});
)

~synths[0].set(\gate, 1);
~synths[0].set(\gate, 0);

~synths[2].set(\gate, 1);
~synths[2].set(\gate, 0);



( /* Exit gracefully */
OSCdef.freeAll;
MIDIdef.freeAll;
(0..~num_keys-1).do({
	arg i;
	~synths[i].free;
});
s.quit;
)