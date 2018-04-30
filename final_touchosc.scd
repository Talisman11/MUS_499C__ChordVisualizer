/*
For my final project, I would like to continue using TouchOSC and SuperCollider, expanding on my TouchOSC project from two weeks ago. The main concept of that one was the ability to +/- 1 by a halfstep for each note, and the ability to toggle which and how many notes were stacked in a chord. I would like to incorporate visualizations in SuperCollider via a GUI, and potentially extend this to MIDI keyboard as well. Theoretically the MIDI keyboard component should not be too hard, but I do not have one of my own, so that might be a little cumbersome.

The final result would be a 3-system interface, using TouchOSC to toggle and play with the note/chord qualities (similar to the top part of most MIDI keyboards, but with unique functions that aren't your typical ADSR envelope or oscillator parameters), visualize it with SuperCollider on the computer (similar to my "Chordal Revolver" concept from last semester), and be able to use a MIDI device as input (worst comes to worst I will map my laptop keyboard to play with for the sake of demo-ing).
*/;
(

~root = 60;
~intervals = (0..11);
~notes = ~root + ~intervals;
~synths = Array.newClear(12);

s.waitForBoot({

	SynthDef.new(\simple, {
		arg note=60, amp=0.6, gate=0, bend=0, hpf=10, lpf=10000, width=0.5,
		    attackTime=0.8, decayTime=1.0, sustainLevel=0.75, releaseTime=3;
		var freq, sig, env, filter, pan;
		env = EnvGen.kr(Env.adsr(attackTime, decayTime, sustainLevel, releaseTime), gate);
		freq = note.midicps * bend.midiratio;

		sig = env * VarSaw.ar(freq, [0,0], width, amp);
		sig = HPF.ar(sig, hpf);
		sig = LPF.ar(sig, lpf);
		sig = sig*env;
		Out.ar(0, sig);
	}).add;

	s.sync;

	// ~s = Synth.new(\simple, [\gate, 1]);

	/* Structure: To pitch bend while a note is being played, a Synth must exist for that note, its gate set to 1 or 0 by keydown
	 * But in this case, does that mean N synths must exist to represent an N-key keyboard, every 12 synths representing a new octave?
	 * Could be a way to modularize that in the sense that each octave is just 12 notes up
	 */

	(0..11).do({
		arg i;
		~synths[i] = Synth.new(\simple);//, [\note, ~notes[i]]);
	});
});
)
~synths[0].set(\gate, 0);


sig * MouseY.kr(0.5, 1);
sig.fold
sig.lag(MouseX.kr(4, 441,1)/SampleRate.ir)