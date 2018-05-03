/*
For my final project, I would like to continue using TouchOSC and SuperCollider, expanding on my TouchOSC project from two weeks ago. The main concept of that one was the ability to +/- 1 by a halfstep for each note, and the ability to toggle which and how many notes were stacked in a chord. I would like to incorporate visualizations in SuperCollider via a GUI, and potentially extend this to MIDI keyboard as well. Theoretically the MIDI keyboard component should not be too hard, but I do not have one of my own, so that might be a little cumbersome.

The final result would be a 3-system interface, using TouchOSC to toggle and play with the note/chord qualities (similar to the top part of most MIDI keyboards, but with unique functions that aren't your typical ADSR envelope or oscillator parameters), visualize it with SuperCollider on the computer (similar to my "Chordal Revolver" concept from last semester), and be able to use a MIDI device as input (worst comes to worst I will map my laptop keyboard to play with for the sake of demo-ing).
*/


/* TouchOSC:
 * Multifader - Pitch bend for each chromatic note
 * Multifader - ADSR
 * Rotary - LPF
 * Rotary - HPF

 */
(

MIDIClient.init;
MIDIIn.connectAll;
MIDIFunc.trace(true);
)


(


~num_keys = 24;// number of keys on the MIDI keyboard
~root = 48;
~intervals = (0..~num_keys);
~notes = ~root + ~intervals;
~synths = Array.newClear(~num_keys);

~bend = 0; ~hpf_c = 10; ~lpf_c = 10000;
s.waitForBoot({
	/* Define our synth */
	SynthDef.new(\simple, {
		arg note=60, amp=0.6, gate=0, phs=0, bend=0,
		    hpf_c=10, lpf_c=10000, hrq=1, lrq=1, width=0.5,
		    attackTime=0.8, decayTime=1.0, sustainLevel=0.75, releaseTime=3;
		var freq, sig, env, filter, pan;


		freq = note.midicps * LFNoise1.kr(1!4).bipolar(0).midiratio * bend.midiratio;
		sig = VarSaw.ar(freq, phs, MouseX.kr(0.01, 0.99), amp) * MouseY.kr(0.5, 0.8, 1);
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
		~synths[i] = Synth.new(\simple, [\note, ~notes[i]]);
	});
});

/* OSCdefs listening to TouchOSC inputs */
OSCdef.new(\master, {
	arg msg;
	var amp = msg[1];
	amp.postln;
	s.volume_(amp.explin(0.01, 1, -60, 6)); // in dB
}, '/1/fader1');

OSCdef.new(\xypad, {
	arg msg;
	var y = msg[1], x = msg[2];

	y.postln;
	(0..~num_keys-1).do({
		arg i;
		~synths[i].set(\hpf_c, y.linexp(0, 1, 100, 22000));
	});
}, '/1/xy1');


/* MIDIdefs listening to MIDI keyboard */
MIDIdef.cc(\cc, {
	arg val, cc, misc1, misc2;
	var value;
	[val, cc, misc1, misc2].postln;
	value = LinLin.kr(val, 0, 127, -2, 2);
	if (cc == 7, {
		~synths[0].set(\bend, value);
	});
});

MIDIdef.noteOn(\noteOn, {
	arg val, num, chan, src;
	// TODO: turn on corresponding synth .set()
});

MIDIdef.noteOff(\noteOff, {
	arg val, num, chan, src;
	// TODO: turn off corresponding synth with .set()
});

)




~synths[0].set(\gate, 1);
~synths[2].set(\gate, 1);