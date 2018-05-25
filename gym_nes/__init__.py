"""Registration code of Gym environments in this package."""
import math
import gym
from .smb_env import SuperMarioBrosEnv

gym.envs.registration.register(
    id='SuperMarioBros-v0',
    entry_point='gym_nes:SuperMarioBrosEnv',
    kwargs={
        'max_episode_steps': math.inf,
        'frame_skip': 1
    },
    nondeterministic=True,
)

__all__ = []
