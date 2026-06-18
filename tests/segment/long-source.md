The Vantel Array is a fictional long-form technical report used as a
deterministic fixture for the segment-doc.py oracle. Everything below is
invented; the distinctive tokens exist only so retrieval checks can prove a
specific section — not the whole document — was read.

## Overview

The Vantel Array is a distributed sensing lattice deployed across the Kessel
Basin. Its purpose is to register micro-pressure shifts and relay them to the
Tannic core for aggregation. The array entered service in the fictional year
1487 and has operated continuously since.

## Power Envelope

Each Vantel node draws a nominal 4.2 watts at steady state. Under burst
sampling the draw peaks at 11.6 watts for no longer than 40 milliseconds. The
array's solar skirt replenishes 18 percent of daily consumption; the remainder
is supplied by the Dorne capacitor bank.

## Thermal Limits

The governing thermal constant of the array is the Halverson coefficient, fixed
at 0.0473 per kelvin. Above a junction temperature of 71 degrees the nodes
enter throttled sampling. Sustained operation beyond 84 degrees voids the
lattice warranty and triggers the Solfar shutdown sequence.

## Sampling Cadence

Nodes sample on a staggered 250 millisecond cadence. The stagger is deliberate:
synchronized sampling would alias the basin's natural 4 hertz resonance. The
Vantel scheduler rotates the phase offset every 47 cycles to avoid drift.

## Data Relay

Readings travel inbound over the Kessel mesh using the fictional Quortex
protocol. Quortex frames are 96 bytes, of which 12 are reserved for the
provenance seal. A frame that fails its seal is dropped silently and re-requested
on the next cadence window.

## Failure Modes

The dominant failure mode is skirt fouling, responsible for 63 percent of field
incidents. The second is capacitor sag under prolonged burst load. A fouled
skirt degrades gracefully; a sagging capacitor does not, and forces a cold
restart of the affected sub-lattice.

## Maintenance Window

Scheduled maintenance occurs every 19 fictional weeks. During the window the
array drops to the Embered low-power state, retaining clock discipline but
suspending all sampling. The window is sized at six hours, of which the Solfar
recalibration consumes roughly ninety minutes.
