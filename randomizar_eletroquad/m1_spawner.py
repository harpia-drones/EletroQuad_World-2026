import cv2
import os
import random
import numpy as np

def generate_aruco(id_marcador):
  abs_path = "/root/PX4-Autopilot/Tools/simulation/gz/worlds/models/bouncing/ArUco_marker/materials/textures"
  try:
    os.makedirs(abs_path, exist_ok=True)
    cv2.imwrite(os.path.join(abs_path, f"aruco_sample.png"), cv2.aruco.generateImageMarker(cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_5X5_1000), id_marcador, 250))
  except Exception as e:
    print(f"Erro ao gerar ArUco: {e}")

def sobrescrever_linha(caminho_arquivo, numero_linha, novo_texto):
    """
    Sobrescreve uma linha específica em um arquivo usando o índice da linha.
    
    :param caminho_arquivo: Caminho para o arquivo .txt
    :param numero_linha: O número da linha que deseja alterar (começando em 1)
    :param novo_texto: O novo conteúdo da linha
    """
    try:
        # 1. Ler todas as linhas do arquivo
        with open(caminho_arquivo, 'r', encoding='utf-8') as arquivo:
            linhas = arquivo.readlines()

        # 2. Verificar se a linha existe (ajustando para índice 0)
        indice = numero_linha - 1
        if 0 <= indice < len(linhas):
            # Substitui a linha (garantindo que haja uma quebra de linha no final)
            linhas[indice] = novo_texto + '\n'
            
            # 3. Gravar as alterações de volta no arquivo
            with open(caminho_arquivo, 'w', encoding='utf-8') as arquivo:
                arquivo.writelines(linhas)
            print(f"Linha {numero_linha} atualizada com sucesso.")
        else:
            print(f"Erro: O arquivo tem apenas {len(linhas)} linhas.")

    except FileNotFoundError:
        print("Erro: Arquivo não encontrado.")
    except Exception as e:
        print(f"Ocorreu um erro inesperado: {e}")

# Exemplo de uso:
# sobrescrever_linha('dados.txt', 3, 'Este é o novo texto da terceira linha')

def randomize_poses():

  padding = 1
  iter_amount = 10
  arena_length = 7
  arena_width = 13

  # gera o ArUco
  chosen_factor = random.randint(3,5)
  generate_aruco(chosen_factor)

  x_coords=[]
  y_coords=[]

  # inclui a plataforma de decolagem apenas pra simplificar a lógica abaixo
  x_coords.append(0)
  y_coords.append(0)

  for i in range(iter_amount):
    while True:
      chosen_x = round(random.uniform(0, arena_length) - (arena_length/2), 8)
      chosen_y = round(random.uniform(0, arena_width) - (arena_width/2), 8)
      for x, y in x_coords, y_coords:
        if pow(chosen_x - x, 2) + pow(chosen_y - y, 2) <= padding:
          distance_flag = True
          break
      if !(distance_flag):
        x_coords.append(chosen_x)
        y_coords.append(chosen_y)
        break
  
  # "remove a plataforma de decolagem". Apenas garante que todas as listas tenham o mesmo comprimento
  x_coords.pop(0)
  y_coords.pop(0)

