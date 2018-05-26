"""Registration code of Gym environments in this package."""
import math
import gym
from .smb_env import SuperMarioBrosEnv


def register():
    gym.envs.registration.register(
        id='NesSuperMarioBros-v0',
        entry_point='gym_nes:SuperMarioBrosEnv',
        kwargs={
            'max_episode_steps': math.inf,
            'frame_skip': 4
        },
        nondeterministic=True,
    )


__all__ = [register]
