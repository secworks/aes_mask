# aes_mask
Experimental core for performing masking of AES by generating noise.

## Status
Not completed does **NOT** work.


## Introduction
[Differential Side-Channel Power Analysis
(DPA)](https://en.wikipedia.org/wiki/Power_analysis#Differential_power_analysis)
is a well-known method to extract secret keys being used against
cryptosystems. Different ciphers require different DPA methods tailored
to the specific cipher.

For [the block cipher AES](https://csrc.nist.gov/publications/detail/fips/197/final) DPA
methods usually focus on the SubBytes() operation in combination with
the AddRoundKey() operation.

Masking is the general term for adding functionality to the cipher to
defeat DPA by making it (practically) infeasible to find the difference
in energy from a bit of the key in a set of power traces. There are many
papers describing masking methods, some of the are even provably
secure. But due to for example glitching, many provably secure masking
methods have been shown not to secure.

Typically the masking methods try to alter the S-boxes by performing a
transform before the SubBytes(), use an altered S-box, peform
AddRoundKey() and then another transform to undo the changes of the
transform. If not, the cipher will not work correctly.

An interesting question related to masking is how expensive the masking
functionality is (in terms of computing or gates, registers etc in
hardware).

This core is my attempt at performing masking. Not by developing a new
transform that modifies the AES implementing, but by adding random power
noise in sync with the AES functionality. A separate core that can work
in parallel with AES and cause variance in power consumption.

Basically the core implements the AES encipher pipeline. But the key
schedule is different. And the S-boxes used are different. The core
operates in something akin to CBC mode and the key is transformed
between next() calls. This *should* cause the noise to vary in between
calls... Or is that bad? Not sure. Lets find out!
