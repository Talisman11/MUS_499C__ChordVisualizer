(

MIDIClient.init;
MIDIIn.connectAll;
MIDIFunc.trace(true);

~cc_23 = 0;
MIDIdef.cc(\cc, {
	arg val, cc, misc1, misc2;

	[val, cc, misc1, misc2].postln;
	if (cc == 23, {
		~cc_23 = val;
	});
});



{
    arg freq=70, phs=0, wdt=0.1, amp=0.2;
    var sig;
    freq = freq * LFNoise1.kr(1!4).bipolar(0).midiratio;
	//sig = VarSaw.ar(freq, phs, MouseX.kr(0.01,0.99)); //TODO: Play with more instruments :)
	sig = VarSaw.ar(freq, phs, LinLin.kr(~cc_23, 0, 128, 0.01, 0.99)); //TODO: Play with more instruments :)
    1.do{
        sig = sig * MouseY.kr(0.5,8,1); //.poll;
        sig = sig.wrap(-1,1);
		// sig = sig.lag(MouseX.kr(4,441,1)/SampleRate.ir);
		sig = RLPF.ar(sig, ExpRand(5000,15000), 0.5);
        sig = RLPF.ar(sig, LFNoise1.kr(1).exprange(1000,2000), 0.5);
    };
    sig = sig * amp;
    sig = Splay.ar(sig);
}.play;
)

s.scope;
