"""Registration code of Gym environments in this package."""
import math
import gym
from .smb_env import SuperMarioBrosEnv


gym.envs.registration.register(
    id='SuperMarioBros-v0',
    entry_point='gym_nes:SuperMarioBrosEnv',
    kwargs={
        'max_episode_steps': math.inf,
        'frame_skip': 4,
        'downsampled_rom': False,
    },
    nondeterministic=True,
)

gym.envs.registration.register(
    id='SuperMarioBros-v1',
    entry_point='gym_nes:SuperMarioBrosEnv',
    kwargs={
        'max_episode_steps': math.inf,
        'frame_skip': 4,
        'downsampled_rom': True,
    },
    nondeterministic=True,
)


gym.envs.registration.register(
    id='SuperMarioBrosNoFrameskip-v0',
    entry_point='gym_nes:SuperMarioBrosEnv',
    kwargs={
        'max_episode_steps': math.inf,
        'frame_skip': 1,
        'downsampled_rom': False,
    },
    nondeterministic=True,
)

gym.envs.registration.register(
    id='SuperMarioBrosNoFrameskip-v1',
    entry_point='gym_nes:SuperMarioBrosEnv',
    kwargs={
        'max_episode_steps': math.inf,
        'frame_skip': 1,
        'downsampled_rom': True,
    },
    nondeterministic=True,
)

__all__ = []
