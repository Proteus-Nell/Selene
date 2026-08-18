"""Global seeding, so every run is reproducible from params plus a seed.

Anything that cannot be reconstructed from `(config, seed, dataset checksum)` is a
reproducibility bug. See docs/PLAN.md 5.3.
"""

from __future__ import annotations

import os
import random

import numpy as np

__all__ = ["DEFAULT_SEED", "seed_everything"]

DEFAULT_SEED = 20260818
"""Default seed. Arbitrary but fixed, so the committed artifacts are stable."""


def seed_everything(seed: int = DEFAULT_SEED) -> np.random.Generator:
    """Seed every source of randomness and return a fresh generator.

    Args:
        seed: The seed to use.

    Returns:
        A `numpy` generator seeded from `seed`. Thread this explicitly through
        call sites rather than reaching for the legacy global `numpy.random`
        functions, which make it impossible to reason about who consumed which
        draws.
    """
    random.seed(seed)
    # Affects the hash randomisation of new subprocesses only, which is why it is
    # set here rather than assumed.
    os.environ["PYTHONHASHSEED"] = str(seed)
    return np.random.default_rng(seed)
