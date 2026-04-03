import random
import numpy as np
import os

def randomize_poses():

  padding = 1
  iter_amount = 10
  arena_length = 7
  arena_width = 13

  valid_angles = [90, 57, 27, 356, 321, 300, 266, 235, 204, 181]
  interval_chosen = []

  # listas a serem zipadas no final
  indexes = []
  x_coords = []
  y_coords = []
  angles = []

  # inclui a plataforma de decolagem apenas pra simplificar a lógica abaixo
  x_coords.append(0)
  y_coords.append(0)

  for i in range(iter_length): # loop para criar os manômetros
    indexes.append(i+1)
    while True: # loop que garante que todas os manômetros estão a uma distância euclidiana mínima entre si
      chosen_x = round(random.uniform(0, arena_length) - (arena_length/2), 8)
      chosen_y = round(random.uniform(0, arena_width) - (arena_width/2), 8)
      distance_flag = False
      for x, y in x_coords, y_coords:
        if pow(chosen_x - x, 2) + pow(chosen_y - y, 2) <= padding:
          distance_flag = True
          break
      if !(distance_flag):
        x_coords.append(chosen_x)
        y_coords.append(chosen_y)
        break

    # escolhe um intervalo entre os ângulos válidos e anexa o valor escolhido dentro do intervalo à lista
    interval = random.randint(1,5)-1
    interval_chosen.append(np.radians(valid_angles[interval]))
    interval_chosen.append(np.radians(valid_angles[interval+1]))
    # TODO: verificar se o sinal deve ser + ou -
    angles.append(random.uniform(interval_chosen[0], interval_chosen[1]) + (np.pi/2))
  
  # "remove a plataforma de decolagem". Apenas garante que todas as listas tenham o mesmo comprimento
  x_coords.pop(0)
  y_coords.pop(0)

  # une todos os parâmetros em uma lista de tuplas
  randomized.append(zip(indexes, x_coords, y_coords, angles))

  return randomized