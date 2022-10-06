from copyreg import remove_extension
from curses.ascii import isdigit
from lib2to3.pytree import convert
from re import S, search
import sys
import os
import configparser
import fileinput
import time

from datetime import datetime
from getpass import getuser
from os import listdir
from os.path import isfile, join

class Gerador_Vhdl(object):
    def __init__(self):
        self.texto = ''
        self.temp = None
        self.troca = None
        self.ini = None
        self.fim = None
        self.criar_ini = ''
        self.vhdl_texto_aux = ""

    def criador_lib(self, texto, config): # Cria as bibliotecas iniciais do arquivo top
        temp = ""
        for nome in config.sections():
            if nome[:10] == 'Biblioteca':
                for n, v in config.items(nome):
                    if n == 'nome':
                        temp += f"library {v};\n"
                    else:
                        temp += f"use {v};\n"
                texto += temp + "\n"
                temp = ""
        return texto

    def criador_entidade(self, texto, config): # Criação da entidade do arquivo top
        texto += f"\nentity {config['Entidade']['nome']} is\n"
        return texto

    def criador_generic(self, texto, config): # Criação do Generic do arquivo top
        temp = ""
        for nome in config.sections():
            if nome == 'Generic':
                texto += "  generic (\n"
                for n, v in config.items(nome):
                    if n[:4] == 'type' and v != 'std_logic_vector':
                        temp += f" {v};\n"
                    elif n[:4] == 'type' and v == 'std_logic_vector':
                        temp += f" {v}"
                    elif n[:6] == 'vector':
                        temp += f"({int(v)-1} downto 0);\n"
                    elif n[:5] == 'valor':
                        if v == 'TRUE' or v == 'FALSE':
                            temp = temp[:-2] + f" := {v};\n"
                        elif v[:1] != 'x':
                            temp = temp[:-2] + f" := {v};\n"
                        else:
                           temp = temp[:-2] + f' := {v[:1]}"{v[1:]}";\n'
                    else:
                        temp += f"{' '*4}{v:<20} : "
                texto += temp + "\n"
        texto = texto[:-3] + "\n"
        texto += "  );\n"
        return texto

    def criador_generic_2(self, texto, config): # Criação do Generic do arquivo top
        temp = ""
        for nome in config.sections():
            if nome == 'Generic':
                texto += "  generic (\n"
                for n, v in config.items(nome):
                    if n[:5] == 'type8' and v != 'std_logic_vector':
                        temp += f" {v};\n"
                    elif n[:5] == 'type8' and v == 'std_logic_vector':
                        temp += f" {v}"
                    elif n[:7] == 'vector8':
                        temp += f"({int(v)-1} downto 0);\n"
                    elif n[:6] == 'valor8':
                        if v == 'TRUE' or v == 'FALSE':
                            temp = temp[:-2] + f" := {v};\n"
                        elif v[:1] != 'x':
                            temp = temp[:-2] + f" := {v};\n"
                        else:
                           temp = temp[:-2] + f' := {v[:1]}"{v[1:]}";\n'
                    elif n[:5] == 'nome8':
                        temp += f"{' '*4}{v:<20} : "
                texto += temp + "\n"
        texto = texto[:-3] + "\n"
        texto += "  );\n"
        return texto

    def criador_portas(self, texto, config): # Criação das portas de entrada e saída
        temp = ""
        texto += "  port (\n"
        for nome in config.sections():
            if nome[:5] == 'Porta':
                for n, v in config.items(nome):
                    if n == 'es' and v == 'in':
                        temp += "  :  in  "
                    elif n == 'es' and v == 'out':
                        temp += "  :  out "
                    elif n == 'type' and v == 'no vector':
                        temp += " std_logic;"
                    elif n == 'type' and v == 'GPIO_SIZE':
                        temp += " std_logic_vector(GPIO_SIZE-1 downto 0);"
                    elif n == 'type' and v[:6] == 'vector':
                        temp += f" std_logic_vector({int(v[7:])-1} downto 0);"
                    elif n == 'type' and v == 'axim':
                        temp += " AXI4L_MASTER_TO_SLAVE;"
                    elif n == 'type' and v == 'axis':
                        temp += " AXI4L_SLAVE_TO_MASTER;"
                    else:
                        temp = f"{' '*4}{v:<15}"
                texto += temp + "\n"
        texto = texto[:-2] + "\n"
        texto += "  );\n"
        texto += "end entity;\n"
        return texto

    def criador_arq(self, texto, config): # Criar arquitetura
        texto = texto + f"\narchitecture {config['Arquitetura']['nome']} of {config['Entidade']['nome']} is \n"
        return texto

    def criador_constant(self, texto, config): # Criação das constantes
        temp = ""
        config.remove_option('Generic','nome8')
        config.remove_option('Generic','valor8')
        config.remove_option('Generic','type8')

        for nome in config.sections():
            if nome == 'Generic':
                for n, v in config.items(nome):
                    if n[:4] == 'type' and v != 'std_logic_vector':
                        temp += f"  {v};\n"
                    elif n[:4] == 'type' and v == 'std_logic_vector':
                        temp += f"  {v}"
                    elif n[:6] == 'vector':
                        temp += f"({int(v)-1} downto 0);\n"
                    elif n[:5] == 'valor':
                        if v == 'TRUE' or v == 'FALSE':
                            temp = temp[:-2] + f" := {v};\n"
                        elif v[:1] != 'x':
                            temp = temp[:-2] + f" := {v};\n"
                        else:
                           temp = temp[:-2] + f' := {v[:1]}"{v[1:]}";\n'
                    else:
                        temp += f"{' '*2}constant {v:<20}:"
                texto += temp 
        return texto

    def criador_sinal(self, texto, config): # Criação dos sinais
        temp = ""
        for nome in config.sections():
            if nome[:5] == 'Sinal':
                for n, v in config.items(nome):
                    if n == 'type' and v == 'no vector':
                        temp += ":  std_logic;"
                    elif n == 'type' and v[:6] == 'vector':
                        temp += f":  std_logic_vector({int(v[7:])-1} downto 0);"
                    elif n == 'type' and v == 'axim':
                        temp += ":  AXI4L_MASTER_TO_SLAVE;"
                    elif n == 'type' and v == 'axis':
                        temp += ":  AXI4L_SLAVE_TO_MASTER;"
                    else:
                        temp = f"{' '*2}signal {v:<20}  "
                texto += temp + "\n"
        texto += f"\nbegin \n"
        return texto

    def criador_map(self, texto, config): # Criação do Port Map do arquivo top
        temp = ""

        if config['Map 56']['check'] == 'FALSE':
            config.remove_section('Map 56')
        else:
            config.remove_option('Map 56','check')

        if config['Map 57']['check'] == 'FALSE':
            config.remove_section('Map 57')
        else:
            config.remove_option('Map 57','check')
        
        if config['Map 61']['check'] == 'FALSE':
            config.remove_section('Map 61')
        else:
            config.remove_option('Map 61','check')

        if config['Map 62']['check'] == 'FALSE':
            config.remove_section('Map 62')
        else:
            config.remove_option('Map 62','check')
        
        if config['Map 63']['check'] == 'FALSE':
            config.remove_section('Map 63')
        else:
            config.remove_option('Map 63','check')

        if config['Map 64']['check'] == 'FALSE':
            config.remove_section('Map 64')
        else:
            config.remove_option('Map 64','check')

        if config['Elif 65']['check'] == 'FALSE':
            config.remove_section('Elif 65')
            config.remove_section('Elif 66')
        else:
            config.remove_option('Elif 65','check')

        for nome in config.sections():
            if nome[:3] == 'Map':
                for n, v in config.items(nome):
                    if n == 'nome':
                        temp += f"\n{' '*2}{v:<20} : "
                    elif n == 'entity' and v[:2] == 'no':
                        temp += f"{v[3:]} \n"
                    elif n == 'entity' and v[:3] == 'yes':
                        temp += f"entity work.{v[4:]} \n"
                    elif n == 'temgeneric' and v == 'yes':
                        temp += f"{' '*2}generic map ( \n"
                    elif n == 'temgeneric' and v == 'no':
                        temp += f"{' '*2}port map ( \n"
                    elif n[:7] == 'generic' and v[:1] != 'x':
                        temp += f"{' '*4}{n[8:]:<18}  =>  {v}, \n"
                    elif n[:7] == 'generic' and v[:1] == 'x':
                        temp += f'    {n[8:]:<18}  =>  {v[:1]}"{v[1:]}", \n'
                    elif n == 'acabougen':
                        temp = temp[:-3] + "\n"
                        temp += f"{' '*2})\n {' '*1}port map ( \n"
                    else:
                        if v[:5] == 'Porta' or v[:5] == 'Sinal': 
                            temp += f"{' '*4}{n:<18}  =>  {config[v]['nome']}, \n"
                        elif v[:1] == 'x':
                            temp += f'    {n:<18}  =>  {v[:1]}"{v[1:]}", \n'
                        else:
                            temp += f"{' '*4}{n:<18}  =>  {v}, \n"
                texto += temp + "\n"
                temp = ""
                texto = texto[:-4] + "\n"
                texto += f"{' '*2});\n"
        return texto

    def criador_map_customizavel(self, texto, config): # Criação do Port Map de arquivo externo
        temp = ""
        for nome in config.sections():
            if nome[:3] == 'Map':
                for n, v in config.items(nome):
                    if n == 'nome':
                        temp += f"\n{' '*2}{v:<20} : "
                    elif n == 'entity' and v[:2] == 'no':
                        temp += f"{v[3:]} \n"
                    elif n == 'entity' and v[:3] == 'yes':
                        temp += f"entity work.{v[4:]} \n"
                    elif n == 'temgeneric' and v == 'yes':
                        temp += f"{' '*2}generic map ( \n"
                    elif n == 'temgeneric' and v == 'no':
                        temp += f"{' '*2}port map ( \n"
                    elif n[:7] == 'generic' and v[:1] != 'x':
                        temp += f"{' '*4}{n[8:]:<18}  =>  {v}, \n"
                    elif n[:7] == 'generic' and v[:1] == 'x':
                        temp += f'    {n[8:]:<18}  =>  {v[:1]}"{v[1:]}", \n'
                    elif n == 'acabougen':
                        temp = temp[:-3] + "\n"
                        temp += f"{' '*2})\n {' '*1}port map ( \n"
                    else:
                        if v[:5] == 'Porta' or v[:5] == 'Sinal': 
                            temp += f"{' '*4}{n:<18}  =>  {config[v]['nome']}, \n"
                        elif v[:1] == 'x':
                            temp += f'    {n:<18}  =>  {v[:1]}"{v[1:]}", \n'
                        else:
                            temp += f"{' '*4}{n:<18}  =>  {v}, \n"
                texto += temp + "\n"
                temp = ""
                texto = texto[:-4] + "\n"
                texto += f"{' '*2});\n"
        return texto

    def criador_ext(self, texto, config): # Criar variaveis externas 
        var = '"deadbeef"'
        enable_ecc = 'enable_dmem_g'
        disabled_ecc = 'disabled_dmem_g'
        enable_dmem = config['Generic']['nome4']
        enable_dmem_ecc = config['Generic']['nome5']

        temp = "\n"
        temp += f"{' '*2}{disabled_ecc} : if not {enable_dmem} generate\n"
        temp += f"{' '*2}begin\n"
        temp += f"{' '*4}{config['Sinal 19']['nome']} <= '0';\n"
        temp += f"{' '*4}{config['Sinal 20']['nome']} <= '1';\n"
        temp += f"{' '*4}{config['Sinal 25']['nome']} <= x{var};\n"
        temp += f"{' '*4}{config['Sinal 52']['nome']} <= '0';\n"
        temp += f"{' '*2}end generate;\n"
        temp += f"{' '*2}{enable_ecc} : if {enable_dmem} and not {enable_dmem_ecc} generate\n{' '*2}begin"

        for nome in config.sections():
            if nome[:4] == 'Elif':
                aux = nome
                for n, v in config.items(nome):
                    if n == 'nome':
                        temp += f"\n{' '*4}{v:<20} : "
                    elif n == 'entity' and v[:2] == 'no':
                        temp += f"{v[3:]} \n"
                    elif n == 'entity' and v[:3] == 'yes':
                        temp += f"entity work.{v[4:]} \n"
                    elif n == 'temgeneric' and v == 'yes':
                        temp += f"{' '*4}generic map ( \n"
                    elif n == 'temgeneric' and v == 'no':
                        temp += f"{' '*4}port map ( \n"
                    elif n[:7] == 'generic' and v[:1] != 'x':
                        temp += f"{' '*6}{n[8:]:<18}  =>  {v}, \n"
                    elif n[:7] == 'generic' and v[:1] == 'x':
                        temp += f'    {n[8:]:<18}  =>  {v[:1]}"{v[1:]}", \n'
                    elif n == 'acabougen':
                        temp = temp[:-3] + "\n"
                        temp += f"{' '*4})\n {' '*3}port map ( \n"
                    else:
                        if v[:5] == 'Porta' or v[:5] == 'Sinal': 
                            temp += f"{' '*6}{n:<18}  =>  {config[v]['nome']}, \n"
                        elif v[:1] == 'x':
                            temp += f'    {n:<18}  =>  {v[:1]}"{v[1:]}", \n'
                        else:
                            temp += f"{' '*5}{n:<18}  =>  {v}, \n"
                texto += temp + "\n"
                temp = ""
                texto = texto[:-4] + "\n"
                texto += f"{' '*4});\n"
                if aux == 'Elif 65':
                    texto += f"{' '*4}{config['Sinal 52']['nome']}  <= '0';\n"
                    texto += f"{' '*2}end generate;\n"
                    texto += f"{' '*2}{enable_ecc} : if {enable_dmem} and {enable_dmem_ecc} generate\n{' '*2}begin"
                else:
                    texto += f"{' '*2}end generate;\n"
                    texto += "end architecture;\n"
        return texto

    def gera_ini_library(self, vhdl_texto, caminho_dir):
        self.contador = 0
        for linha in vhdl_texto:
            if linha[:7] == 'library':
                self.criar_ini += f"[Biblioteca {self.contador}]\n{'nome'} = {linha[8:]}"
                self.contador += 1
            elif linha[:3] == 'use':
                self.criar_ini += f"use{self.contador} = {linha[4:]}"
                self.contador += 1
            elif linha[:6] == 'entity':
                self.criar_ini += f"[Entidade]\n{'nome'} = {linha[7:16]}"
        
        self.criar_ini += "\n"
        self.criar_ini = self.criar_ini.replace(";", "")

        destino_arq = open(caminho_dir + '/barramento.ini', 'w')
        destino_arq.write(self.criar_ini)
        destino_arq.close()

    def gera_ini_generic(self, vhdl_texto, config, caminho_dir):
        self.contador = 0
        for linha in vhdl_texto:
            if linha[2:9] == 'generic':
                self.criar_ini += "[Generic]\n"
            else:
                self.temp = linha.find(':')
                self.ini = str(linha[:self.temp])
                self.fim = str(linha[self.temp:])
                if self.temp != -1:
                    if self.fim[2:18] == 'std_logic_vector':
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:18]}\nvector{self.contador} = {int(self.fim[19:21])+1}\nvalor{self.contador} = x{self.fim[37:45]}\n"
                        self.contador += 1
                    elif self.ini[4:13] == 'GPIO_SIZE':
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:9]}\nvalor{self.contador} = {config['GPIO']['largura']}\n"
                        self.contador += 1
                    elif self.ini[4:12] == 'HARV_TMR':
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:9]}\nvalor{self.contador} = {config['Harv']['harv_tmr']}\n"
                        self.contador += 1
                    elif self.ini[4:12] == 'HARV_ECC':
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:9]}\nvalor{self.contador} = {config['Harv']['harv_ecc']}\n"
                        self.contador += 1
                    elif self.ini[4:18] == 'DMEM_BASE_ADDR':
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:9]}\nvalor{self.contador} = {config['Memoria']['endereco_memoria']}\n"
                        self.contador += 1
                    elif self.ini[4:18] == 'DMEM_HIGH_ADDR':
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:9]}\nvalor{self.contador} = {config['Memoria']['tamanho']}\n"
                        self.contador += 1
                    else:
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:9]}\nvalor{self.contador} = {self.fim[12:]}\n"
                        self.contador += 1

        self.criar_ini += "\n"
        self.criar_ini = self.criar_ini.replace(";", "")
        self.criar_ini = self.criar_ini.replace("  ", "")
        self.criar_ini = self.criar_ini.replace(":=", "")

        destino_arq = open(caminho_dir + '/barramento.ini', 'w')
        destino_arq.write(self.criar_ini)
        destino_arq.close()

    def gera_ini_port(self, vhdl_texto, caminho_dir):
        self.contador = 0
        for linha in vhdl_texto:
            self.temp = linha.find(':')
            self.ini = str(linha[:self.temp])
            self.fim = str(linha[self.temp:])
            if self.temp != -1:
                self.criar_ini += f"[Porta {self.contador}]\n"
                if self.fim[6:22] == 'std_logic_vector':
                    if self.fim[23:32] == 'GPIO_SIZE':
                        self.criar_ini += f"nome = {self.ini[4:]}\nes = {self.fim[2:5]}\ntype = GPIO_SIZE\n"
                    else:
                        self.criar_ini += f"nome = {self.ini[4:]}\nes = {self.fim[2:5]}\ntype = vector {int(self.fim[23:25])+1}\n"
                    self.contador += 1
                elif self.fim[6:13] == 'AXI4L_M':
                    self.criar_ini += f"nome = {self.ini[4:]}\nes = {self.fim[2:5]}\ntype = axim\n"
                    self.contador += 1
                elif self.fim[6:13] == 'AXI4L_S':
                    self.criar_ini += f"nome = {self.ini[4:]}\nes = {self.fim[2:5]}\ntype = axis\n"
                    self.contador += 1
                else:
                    self.criar_ini += f"nome = {self.ini[4:]}\nes = {self.fim[2:5]}\ntype = no vector\n"
                    self.contador += 1

            elif linha[:12] == 'architecture':
                    self.criar_ini += f"[Arquitetura]\n{'nome'} = {linha[13:17]}"

        self.criar_ini += "\n"
        self.criar_ini = self.criar_ini.replace(";", "")
        self.contador = 0

        destino_arq = open(caminho_dir + '/barramento.ini', 'w')
        destino_arq.write(self.criar_ini)
        destino_arq.close()

    def gera_ini_signal(self, vhdl_texto, caminho_dir):
        for linha in vhdl_texto:
            self.temp = linha.find(':')
            self.ini = str(linha[:self.temp])
            self.fim = str(linha[self.temp:])
            if self.temp != -1:
                self.criar_ini += f"[Sinal {self.contador}]\n"
                if self.fim[2:18] == 'std_logic_vector':
                    self.criar_ini += f"nome = {self.ini[9:]}\ntype = vector {int(self.fim[19:21])+1}\n"
                    self.contador += 1
                else:
                    self.criar_ini += f"nome = {self.ini[9:]}\ntype = no vector\n"
                    self.contador += 1

        self.criar_ini += "\n"
        self.criar_ini = self.criar_ini.replace(";", "")

        destino_arq = open(caminho_dir + '/barramento.ini', 'w')
        destino_arq.write(self.criar_ini)
        destino_arq.close()

    def gera_ini_signal_bus(self, vhdl_texto, caminho_dir):
        for linha in vhdl_texto:
            self.temp = linha.find(':')
            self.ini = str(linha[:self.temp])
            self.fim = str(linha[self.temp:])
            if self.temp != -1:
                self.criar_ini += f"[Sinal {self.contador}]\n"
                if self.fim[2:23] == 'AXI4L_MASTER_TO_SLAVE':
                    self.criar_ini += f"nome = {self.ini[9:]}\ntype = axim\n"
                    self.contador += 1
                else:
                    self.criar_ini += f"nome = {self.ini[9:]}\ntype = axis\n"
                    self.contador += 1

        self.criar_ini += "\n"
        self.criar_ini = self.criar_ini.replace(";", "")

        destino_arq = open(caminho_dir + '/barramento.ini', 'w')
        destino_arq.write(self.criar_ini)
        destino_arq.close()

    def gera_ini_signal_manual(self, caminho_dir):
        self.criar_ini += f"[Sinal {self.contador}]\nnome: mem_ev_rdata_valid_w\ntype= no vector\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: mem_ev_sb_error_w\ntype= no vector\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: mem_ev_db_error_w\ntype= no vector\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: mem_ev_error_addr_w\ntype= vector 3\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: mem_ev_ecc_addr_w\ntype= vector 32\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: mem_ev_enc_data_w\ntype= vector 39\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: mem_ev_event_w\ntype= no vector\n"
        self.contador +=1

        destino_arq = open(caminho_dir + '/barramento.ini', 'w')
        destino_arq.write(self.criar_ini)
        destino_arq.close()

    def gera_ini_map_no_generic(self, vhdl_texto, caminho_dir):
        for linha in vhdl_texto:
            if linha[:6] == 'entity':
                self.criar_ini += f"[Map {self.contador}]\nnome: {linha[7:]}"
                if linha[7:19] == "axi4l_master":
                    self.criar_ini += f"entity: no {linha[7:]}"
                else:
                    self.criar_ini += f"entity: yes {linha[7:]}"
                self.criar_ini += f"temgeneric: no\n"
                self.contador += 1

            self.temp = linha.find(':')
            self.ini = str(linha[:self.temp])
            self.fim = str(linha[self.temp:])

            if self.temp != -1:
                self.criar_ini += f"{self.ini[4:]} : \n"

        self.criar_ini = self.criar_ini.replace("  ", "")

        destino_arq = open(caminho_dir + '/barramento.ini', 'w')
        destino_arq.write(self.criar_ini)
        destino_arq.close()

    def gera_ini_map_generic(self, vhdl_texto, caminho_dir):
        for linha in vhdl_texto:
            if linha[:6] == 'entity':
                self.criar_ini += f"[Map {self.contador}]\nnome: {linha[7:]}"
                if linha[7:23] == "reset_controller" or linha[7:23] == "mem_interconnect" or linha[7:27] == "axi4l_interconnect_4" :
                    self.criar_ini += f"entity: yes {linha[7:]}"
                else:
                    self.criar_ini += f"entity: no {linha[7:]}"
                self.criar_ini += f"temgeneric: yes\n"
                self.contador += 1

            self.temp = linha.find(':')
            self.ini = str(linha[:self.temp])
            self.fim = str(linha[self.temp:])

            if self.temp != -1:
                self.criar_ini += f"generic {self.ini[4:]} : \n"
                
        self.criar_ini += f"acabougen:\n"
        self.criar_ini = self.criar_ini.replace("  ", "")

        destino_arq = open(caminho_dir + '/barramento.ini', 'w')
        destino_arq.write(self.criar_ini)
        destino_arq.close()

    def gera_ini_map_memory(self, vhdl_texto, caminho_dir):
        for linha in vhdl_texto:
            if linha[:6] == 'entity':
                self.criar_ini += f"[Elif {self.contador}]\nnome: {linha[7:]}"
                if linha[7:23] == "reset_controller" or linha[7:23] == "mem_interconnect" or linha[7:27] == "axi4l_interconnect_4" :
                    self.criar_ini += f"entity: yes {linha[7:]}"
                else:
                    self.criar_ini += f"entity: no {linha[7:]}"
                self.criar_ini += f"temgeneric: yes\n"
                self.contador += 1

            self.temp = linha.find(':')
            self.ini = str(linha[:self.temp])
            self.fim = str(linha[self.temp:])

            if self.temp != -1:
                self.criar_ini += f"generic {self.ini[4:]} : \n"
                
        self.criar_ini += f"acabougen:\n"
        self.criar_ini = self.criar_ini.replace("  ", "")

        destino_arq = open(caminho_dir + '/barramento.ini', 'w')
        destino_arq.write(self.criar_ini)
        destino_arq.close()

    def criar_processador(self, config_axi, config):
        config_axi['Map 56']['check'] = config['Harv']['check_harv']
        config_axi['Map 56']['nome'] = str(config_axi['Map 56']['nome']).replace(" is","_u")
        config_axi['Map 56']['entity'] = str(config_axi['Map 56']['entity']).replace(" is","")
        config_axi['Map 56']['generic PROGRAM_START_ADDR'] = config_axi['Generic']['nome0']
        config_axi['Map 56']['generic TMR_CONTROL'] = config_axi['Generic']['nome1']
        config_axi['Map 56']['generic TMR_ALU'] = config_axi['Generic']['nome1']
        config_axi['Map 56']['generic ECC_REGFILE'] = config_axi['Generic']['nome2']
        config_axi['Map 56']['generic ECC_PC'] = config_axi['Generic']['nome2']
        config_axi['Map 56']['rstn_i'] = config_axi['Sinal 1']['nome']
        config_axi['Map 56']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 56']['start_i'] = config_axi['Porta 3']['nome']
        config_axi['Map 56']['poweron_rstn_i'] = config_axi['Porta 0']['nome']
        config_axi['Map 56']['wdt_rstn_i'] = config_axi['Sinal 3']['nome']
        config_axi['Map 56']['imem_rden_o'] = config_axi['Sinal 4']['nome']
        config_axi['Map 56']['imem_gnt_i'] = config_axi['Sinal 6']['nome']
        config_axi['Map 56']['imem_err_i'] = config_axi['Sinal 7']['nome']
        config_axi['Map 56']['imem_addr_o'] = config_axi['Sinal 5']['nome']
        config_axi['Map 56']['imem_rdata_i'] = config_axi['Sinal 8']['nome']
        config_axi['Map 56']['dmem_wren_o'] = config_axi['Sinal 9']['nome']
        config_axi['Map 56']['dmem_rden_o'] = config_axi['Sinal 10']['nome']
        config_axi['Map 56']['dmem_gnt_i'] = config_axi['Sinal 11']['nome']
        config_axi['Map 56']['dmem_err_i'] = config_axi['Sinal 12']['nome']
        config_axi['Map 56']['dmem_addr_o'] = config_axi['Sinal 13']['nome']
        config_axi['Map 56']['dmem_wdata_o'] = config_axi['Sinal 14']['nome']
        config_axi['Map 56']['dmem_wstrb_o'] = config_axi['Sinal 15']['nome']
        config_axi['Map 56']['dmem_rdata_i'] = config_axi['Sinal 16']['nome']
        config_axi['Map 56']['ext_interrupt_i'] = 'x00'
        config_axi['Map 56']['ext_event_i'] = config_axi['Sinal 54']['nome']

        if config['Barramento']['check_timeout'] == 'FALSE':
            config_axi['Map 56']['periph_timeout_i'] = config_axi['Sinal 35']['nome']
        else:
            config_axi['Map 56']['periph_timeout_i'] = '0'

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_reset(self, config_axi):
        config_axi['Map 55']['nome'] = str(config_axi['Map 55']['nome']).replace(" is","_u")
        config_axi['Map 55']['entity'] = str(config_axi['Map 55']['entity']).replace(" is","")
        config_axi['Map 55']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 55']['poweron_rstn_i'] = config_axi['Porta 0']['nome']
        config_axi['Map 55']['btn_rstn_i'] = config_axi['Porta 1']['nome']
        config_axi['Map 55']['wdt_rstn_i'] = config_axi['Sinal 3']['nome']
        config_axi['Map 55']['periph_timeout_i'] = config_axi['Sinal 35']['nome']
        config_axi['Map 55']['ext_rstn_o'] = config_axi['Sinal 0']['nome']
        config_axi['Map 55']['proc_rstn_o'] = config_axi['Sinal 1']['nome']
        config_axi['Map 55']['periph_rstn_o'] = config_axi['Sinal 2']['nome']
        config_axi['Map 55']['ext_periph_rstn_o'] = config_axi['Porta 4']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_mem_interconnect(self, config_axi, config):
        config_axi['Map 57']['check'] = config['Harv']['check_harv']
        config_axi['Map 57']['nome'] = str(config_axi['Map 57']['nome']).replace(" is","_u")
        config_axi['Map 57']['entity'] = str(config_axi['Map 57']['entity']).replace(" is","")
        config_axi['Map 57']['generic mem0_base_addr'] = config_axi['Generic']['nome6']
        config_axi['Map 57']['generic mem0_high_addr'] = config_axi['Generic']['nome7']
        config_axi['Map 57']['imem_rden_i'] = config_axi['Sinal 4']['nome']
        config_axi['Map 57']['imem_addr_i'] = config_axi['Sinal 5']['nome']
        config_axi['Map 57']['imem_gnt_o'] = config_axi['Sinal 6']['nome']
        config_axi['Map 57']['imem_err_o'] = config_axi['Sinal 7']['nome']
        config_axi['Map 57']['imem_rdata_o'] = config_axi['Sinal 8']['nome']
        config_axi['Map 57']['dmem_wren_i'] = config_axi['Sinal 9']['nome']
        config_axi['Map 57']['dmem_rden_i'] = config_axi['Sinal 10']['nome']
        config_axi['Map 57']['dmem_gnt_o'] = config_axi['Sinal 11']['nome']
        config_axi['Map 57']['dmem_err_o'] = config_axi['Sinal 12']['nome']
        config_axi['Map 57']['dmem_addr_i'] = config_axi['Sinal 13']['nome']
        config_axi['Map 57']['dmem_wdata_i'] = config_axi['Sinal 14']['nome']
        config_axi['Map 57']['dmem_wstrb_i'] = config_axi['Sinal 15']['nome']
        config_axi['Map 57']['dmem_rdata_o'] = config_axi['Sinal 16']['nome']
        config_axi['Map 57']['mem0_wren_o'] = config_axi['Sinal 17']['nome']
        config_axi['Map 57']['mem0_rden_o'] = config_axi['Sinal 18']['nome']
        config_axi['Map 57']['mem0_gnt_i'] = config_axi['Sinal 19']['nome']
        config_axi['Map 57']['mem0_err_i'] = config_axi['Sinal 20']['nome']
        config_axi['Map 57']['mem0_prot_o'] = config_axi['Sinal 21']['nome']
        config_axi['Map 57']['mem0_addr_o'] = config_axi['Sinal 22']['nome']
        config_axi['Map 57']['mem0_wdata_o'] = config_axi['Sinal 23']['nome']
        config_axi['Map 57']['mem0_wstrb_o'] = config_axi['Sinal 24']['nome']
        config_axi['Map 57']['mem0_rdata_i'] = config_axi['Sinal 25']['nome']
        config_axi['Map 57']['mem1_wren_o'] = config_axi['Sinal 26']['nome']
        config_axi['Map 57']['mem1_rden_o'] = config_axi['Sinal 27']['nome']
        config_axi['Map 57']['mem1_gnt_i'] = config_axi['Sinal 28']['nome']
        config_axi['Map 57']['mem1_err_i'] = config_axi['Sinal 29']['nome']
        config_axi['Map 57']['mem1_prot_o'] = config_axi['Sinal 30']['nome']
        config_axi['Map 57']['mem1_addr_o'] = config_axi['Sinal 31']['nome']
        config_axi['Map 57']['mem1_wdata_o'] = config_axi['Sinal 32']['nome']
        config_axi['Map 57']['mem1_wstrb_o'] = config_axi['Sinal 33']['nome']
        config_axi['Map 57']['mem1_rdata_i'] = config_axi['Sinal 34']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_axi4l_master(self, config_axi, config):
        config_axi['Map 58']['nome'] = str(config_axi['Map 58']['nome']).replace(" is","_u")
        config_axi['Map 58']['entity'] = str(config_axi['Map 58']['entity']).replace(" is","")
        config_axi['Map 58']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 58']['wren_i'] = config_axi['Sinal 26']['nome']
        config_axi['Map 58']['rden_i'] = config_axi['Sinal 27']['nome']
        config_axi['Map 58']['gnt_o'] = config_axi['Sinal 28']['nome']
        config_axi['Map 58']['err_o'] = config_axi['Sinal 29']['nome']
        config_axi['Map 58']['prot_i'] = config_axi['Sinal 30']['nome']
        config_axi['Map 58']['addr_i'] = config_axi['Sinal 31']['nome']
        config_axi['Map 58']['wdata_i'] = config_axi['Sinal 32']['nome']
        config_axi['Map 58']['wstrb_i'] = config_axi['Sinal 33']['nome']
        config_axi['Map 58']['rdata_o'] = config_axi['Sinal 34']['nome']
        config_axi['Map 58']['master_o'] = config_axi['Sinal 36']['nome']
        config_axi['Map 58']['slave_i'] = config_axi['Sinal 37']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 58']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 58']['rstn_i'] = config_axi['Sinal 2']['nome']

        if config['Barramento']['check_timeout'] == 'FALSE':
            config_axi['Map 58']['timeout_o'] = config_axi['Sinal 35']['nome']
        else:
            config_axi['Map 58']['timeout_o'] = 'open'

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_axi4l_interconnect(self, config_axi, config):
        config_axi['Map 59']['nome'] = str(config_axi['Map 59']['nome']).replace(" is","_u")
        config_axi['Map 59']['entity'] = str(config_axi['Map 59']['entity']).replace(" is","")
        config_axi['Map 59']['generic slave0_base_addr'] = config['Barramento']['endereco']
        config_axi['Map 59']['generic slave0_high_addr'] = 'x00000FFF'
        config_axi['Map 59']['generic slave1_base_addr'] = config['UART']['endereco']
        config_axi['Map 59']['generic slave1_high_addr'] = 'x8000001F'
        config_axi['Map 59']['generic slave2_base_addr'] = 'x80000100'
        config_axi['Map 59']['generic slave2_high_addr'] = 'x80000103'
        config_axi['Map 59']['generic slave3_base_addr'] = config['GPIO']['tamanho']
        config_axi['Map 59']['generic slave3_high_addr'] = 'x80000207'
        config_axi['Map 59']['generic slave4_base_addr'] = 'x80000300'
        config_axi['Map 59']['generic slave4_high_addr'] = 'x80000303'
        config_axi['Map 59']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 59']['master_i'] = config_axi['Sinal 36']['nome']
        config_axi['Map 59']['slave_o'] = config_axi['Sinal 37']['nome']
        config_axi['Map 59']['master0_o'] = config_axi['Sinal 38']['nome']
        config_axi['Map 59']['slave0_i'] = config_axi['Sinal 39']['nome']

        if config['UART']['check_uart'] == 'TRUE':
            config_axi['Map 59']['master1_o'] = config_axi['Sinal 40']['nome']
            config_axi['Map 59']['slave1_i'] = config_axi['Sinal 41']['nome']
        else:
            config_axi['Map 59']['master1_o'] = 'open'
            config_axi['Map 59']['slave1_i'] = 'AXI4L_S2M_DECERR'

        if config['Barramento']['check_wdt'] == 'TRUE':
            config_axi['Map 59']['master2_o'] = config_axi['Sinal 42']['nome']
            config_axi['Map 59']['slave2_i'] = config_axi['Sinal 43']['nome']
        else:
            config_axi['Map 59']['master2_o'] = 'open'
            config_axi['Map 59']['slave2_i'] = 'AXI4L_S2M_DECERR'
        
        if config['GPIO']['check_gpio'] == 'TRUE':
            config_axi['Map 59']['master3_o'] = config_axi['Sinal 44']['nome']
            config_axi['Map 59']['slave3_i'] = config_axi['Sinal 45']['nome']
        else:
            config_axi['Map 59']['master3_o'] = 'open'
            config_axi['Map 59']['slave3_i'] = 'AXI4L_S2M_DECERR'

        if config['Acelerador']['check_hsi'] == 'TRUE':
            config_axi['Map 59']['master4_o'] = config_axi['Sinal 46']['nome']
            config_axi['Map 59']['slave4_i'] = config_axi['Sinal 47']['nome']
        else:
            config_axi['Map 59']['master4_o'] = 'open'
            config_axi['Map 59']['slave4_i'] = 'AXI4L_S2M_DECERR'

        config_axi['Map 59']['ext_master_o'] = 'open'
        config_axi['Map 59']['ext_slave_i'] = 'AXI4L_S2M_DECERR'

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 59']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 59']['rstn_i'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_axi4l_rom(self, config_axi, config):
        config_axi['Map 60']['nome'] = str(config_axi['Map 60']['nome']).replace(" is","_u")
        config_axi['Map 60']['entity'] = str(config_axi['Map 60']['entity']).replace(" is","")
        config_axi['Map 60']['generic base_addr'] = config['Barramento']['endereco']
        config_axi['Map 60']['generic high_addr'] = 'x00000FFF'
        config_axi['Map 60']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 60']['master_i'] = config_axi['Sinal 38']['nome']
        config_axi['Map 60']['slave_o'] = config_axi['Sinal 39']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 60']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 60']['rstn_i'] = config_axi['Sinal 2']['nome']


        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_uart(self, config_axi, config):
        config_axi['Map 61']['check'] = config['UART']['check_uart']
        config_axi['Map 61']['nome'] = str(config_axi['Map 61']['nome']).replace(" is","_u")
        config_axi['Map 61']['entity'] = str(config_axi['Map 61']['entity']).replace(" is","")
        config_axi['Map 61']['generic base_addr'] = config['UART']['endereco']
        config_axi['Map 61']['generic high_addr'] = 'x8000001F'
        config_axi['Map 61']['generic fifo_size'] = config['UART']['profundidade_fifo']
        config_axi['Map 61']['master_i'] = config_axi['Sinal 40']['nome']
        config_axi['Map 61']['slave_o'] = config_axi['Sinal 41']['nome']
        config_axi['Map 61']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 61']['uart_rx_i'] = config_axi['Porta 5']['nome']
        config_axi['Map 61']['uart_tx_o'] = config_axi['Porta 6']['nome']
        config_axi['Map 61']['uart_cts_i'] = config_axi['Porta 7']['nome']
        config_axi['Map 61']['uart_rts_o'] = config_axi['Porta 8']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 61']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 61']['rstn_i'] = config_axi['Sinal 2']['nome']


        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_wdt(self, config_axi, config):
        config_axi['Map 62']['check'] = config['Barramento']['check_wdt']
        config_axi['Map 62']['nome'] = str(config_axi['Map 62']['nome']).replace(" is","_u")
        config_axi['Map 62']['entity'] = str(config_axi['Map 62']['entity']).replace(" is","")
        config_axi['Map 62']['generic base_addr'] = 'x80000100'
        config_axi['Map 62']['generic high_addr'] = 'x80000103'
        config_axi['Map 62']['master_i'] = config_axi['Sinal 37']['nome']
        config_axi['Map 62']['slave_o'] = config_axi['Sinal 38']['nome']
        config_axi['Map 62']['ext_rstn_i'] = config_axi['Sinal 0']['nome']
        config_axi['Map 62']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 62']['wdt_rstn_o'] = config_axi['Sinal 3']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 62']['periph_rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 62']['periph_rstn_i'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_gpio(self, config_axi, config):
        config_axi['Map 63']['check'] = config['GPIO']['check_gpio']
        config_axi['Map 63']['nome'] = str(config_axi['Map 63']['nome']).replace(" is","_u")
        config_axi['Map 63']['entity'] = str(config_axi['Map 63']['entity']).replace(" is","")
        config_axi['Map 63']['generic base_addr'] = config['GPIO']['tamanho']
        config_axi['Map 63']['generic high_addr'] = 'x80000207'
        config_axi['Map 63']['generic gpio_size'] = config_axi['Generic']['nome8']
        config_axi['Map 63']['master_i'] = config_axi['Sinal 44']['nome']
        config_axi['Map 63']['slave_o'] = config_axi['Sinal 45']['nome']
        config_axi['Map 63']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 63']['tri_o'] = config_axi['Porta 9']['nome']
        config_axi['Map 63']['rports_i'] = config_axi['Porta 10']['nome']
        config_axi['Map 63']['wports_o'] = config_axi['Porta 11']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 63']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 63']['rstn_i'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_acelerador(self, config_axi, config):
        config_axi['Map 64']['check'] = config['Acelerador']['check_hsi']
        config_axi['Map 64']['nome'] = str(config_axi['Map 64']['nome']).replace(" is","_u")
        config_axi['Map 64']['entity'] = str(config_axi['Map 64']['entity']).replace(" is","")
        config_axi['Map 64']['generic c_s00_axi_data_width'] = 'x80000300'
        config_axi['Map 64']['generic c_s00_axi_addr_width'] = 'x80000303'
        config_axi['Map 64']['s00_axi_aclk'] = config_axi['Porta 2']['nome']
        config_axi['Map 64']['s00_axi_awvalid'] = 'axi_slave4_master_w.awvalid'
        config_axi['Map 64']['s00_axi_wvalid'] = 'axi_slave4_master_w.wvalid'
        config_axi['Map 64']['s00_axi_bvalid'] = 'axi_slave4_slave_w.bvalid'
        config_axi['Map 64']['s00_axi_arvalid'] = 'axi_slave4_master_w.arvalid'
        config_axi['Map 64']['s00_axi_rvalid'] = 'axi_slave4_slave_w.rvalid'
        config_axi['Map 64']['s00_axi_awready'] = 'axi_slave4_slave_w.awready'
        config_axi['Map 64']['s00_axi_wready'] = 'axi_slave4_slave_w.wready'
        config_axi['Map 64']['s00_axi_bready'] = 'axi_slave4_master_w.bready'
        config_axi['Map 64']['s00_axi_arready'] = 'axi_slave4_slave_w.arready'
        config_axi['Map 64']['s00_axi_rready'] = 'axi_slave4_master_w.rready'
        config_axi['Map 64']['s00_axi_awaddr'] = 'axi_slave4_master_w.awaddr'
        config_axi['Map 64']['s00_axi_awprot'] = 'axi_slave4_master_w.awprot'
        config_axi['Map 64']['s00_axi_wdata'] = 'axi_slave4_master_w.wdata'
        config_axi['Map 64']['s00_axi_wstrb'] = 'axi_slave4_master_w.wstrb'
        config_axi['Map 64']['s00_axi_bresp'] = 'axi_slave4_slave_w.bresp'
        config_axi['Map 64']['s00_axi_araddr'] = 'axi_slave4_master_w.araddr'
        config_axi['Map 64']['s00_axi_arprot'] = 'axi_slave4_master_w.arprot'
        config_axi['Map 64']['s00_axi_rdata'] = 'axi_slave4_slave_w.rdata'
        config_axi['Map 64']['s00_axi_rresp'] = 'axi_slave4_slave_w.rresp'

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 64']['s00_axi_aresetn'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 64']['s00_axi_aresetn'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_memory(self, config_axi, config):
        config_axi['Elif 65']['check'] = config['Memoria']['check_memoria']
        config_axi['Elif 65']['nome'] = str(config_axi['Elif 65']['nome']).replace(" is","_u")
        config_axi['Elif 65']['entity'] = str(config_axi['Elif 65']['entity']).replace(" is","")
        config_axi['Elif 65']['generic base_addr'] = config_axi['Generic']['nome6']
        config_axi['Elif 65']['generic high_addr'] = config_axi['Generic']['nome7']
        config_axi['Elif 65']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Elif 65']['s_wr_ready_o'] = 'open'
        config_axi['Elif 65']['s_rd_ready_o'] = 'open'
        config_axi['Elif 65']['s_wr_en_i'] = config_axi['Sinal 17']['nome']
        config_axi['Elif 65']['s_rd_en_i'] = config_axi['Sinal 18']['nome']
        config_axi['Elif 65']['s_done_o'] = config_axi['Sinal 19']['nome']
        config_axi['Elif 65']['s_error_o'] = config_axi['Sinal 20']['nome']
        config_axi['Elif 65']['s_addr_i'] = config_axi['Sinal 22']['nome']
        config_axi['Elif 65']['s_wdata_i'] = config_axi['Sinal 23']['nome']
        config_axi['Elif 65']['s_wstrb_i'] = config_axi['Sinal 24']['nome']
        config_axi['Elif 65']['s_rdata_o'] = config_axi['Sinal 25']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Elif 65']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Elif 65']['rstn_i'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_memory2(self, config_axi, config):
        config_axi['Elif 66']['nome'] = str(config_axi['Elif 66']['nome']).replace(" is","_ecc_u")
        config_axi['Elif 66']['entity'] = str(config_axi['Elif 66']['entity']).replace(" is","")
        config_axi['Elif 66']['generic base_addr'] = config_axi['Generic']['nome6']
        config_axi['Elif 66']['generic high_addr'] = config_axi['Generic']['nome7']
        config_axi['Elif 66']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Elif 66']['s_wr_ready_o'] = 'open'
        config_axi['Elif 66']['s_rd_ready_o'] = 'open'
        config_axi['Elif 66']['s_wr_en_i'] = config_axi['Sinal 17']['nome']
        config_axi['Elif 66']['s_rd_en_i'] = config_axi['Sinal 18']['nome']
        config_axi['Elif 66']['s_done_o'] = config_axi['Sinal 19']['nome']
        config_axi['Elif 66']['s_error_o'] = config_axi['Sinal 20']['nome']
        config_axi['Elif 66']['s_addr_i'] = config_axi['Sinal 22']['nome']
        config_axi['Elif 66']['s_wdata_i'] = config_axi['Sinal 23']['nome']
        config_axi['Elif 66']['s_wstrb_i'] = config_axi['Sinal 24']['nome']
        config_axi['Elif 66']['s_rdata_o'] = config_axi['Sinal 25']['nome']
        config_axi['Elif 66']['ev_rdata_valid_o'] = config_axi['Sinal 48']['nome']
        config_axi['Elif 66']['ev_sb_error_o'] = config_axi['Sinal 49']['nome']
        config_axi['Elif 66']['ev_db_error_o'] = config_axi['Sinal 50']['nome']
        config_axi['Elif 66']['ev_error_addr_o'] = config_axi['Sinal 51']['nome']
        config_axi['Elif 66']['ev_ecc_addr_o'] = config_axi['Sinal 52']['nome']
        config_axi['Elif 66']['ev_enc_data_o'] = config_axi['Sinal 53']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Elif 66']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Elif 66']['rstn_i'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def verifica_ini(self, config_axi, config):
        config_axi['Generic']['valor1'] = config['Harv']['harv_tmr']
        config_axi['Generic']['valor2'] = config['Harv']['harv_ecc']
        config_axi['Generic']['valor8'] = config['GPIO']['largura']
        config_axi['Map 63']['generic base_addr'] = config['GPIO']['tamanho']
        config_axi['Generic']['valor6'] = config['Memoria']['endereco_memoria']
        config_axi['Generic']['valor7'] = config['Memoria']['tamanho']
        config_axi['Map 61']['generic fifo_size'] = config['UART']['profundidade_fifo']
        config_axi['Map 61']['generic base_addr'] = config['UART']['endereco']
        config_axi['Map 60']['generic base_addr'] = config['Barramento']['endereco']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def gera_vhdl(self, arq_vhd, arq_ini, arq_ext): # Função para controlar criação de cada etapa
        caminho_arq = sys.argv[0]
        caminho_arq = os.path.abspath(caminho_arq)
        caminho_dir = os.path.dirname(caminho_arq)

        config = configparser.ConfigParser()
        config.read(arq_ini)

        config_path = configparser.ConfigParser()
        config_path.read(caminho_dir + '/path.ini')
        
        config_axi = configparser.SafeConfigParser()
        config_axi.read(caminho_dir + '/barramento.ini')

        top_vhd = open(caminho_dir + config_path['Path']['harv'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()

        top_vhd_aux = open(caminho_dir + config_path['Path']['barramento'], 'r')
        vhdl_axi = top_vhd_aux.readlines()
        top_vhd_aux.close()

        del vhdl_texto[104:]
        del vhdl_axi[:65]
        del vhdl_axi[22:]

        self.gera_ini_library(vhdl_texto[:10], caminho_dir)
        self.gera_ini_generic(vhdl_texto[10:23], config, caminho_dir)
        self.gera_ini_port(vhdl_texto[26:55], caminho_dir)
        self.gera_ini_signal(vhdl_texto[55:], caminho_dir)
        self.gera_ini_signal_bus(vhdl_axi, caminho_dir)
        self.gera_ini_signal_manual(caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['reset'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[20:]
        self.gera_ini_map_no_generic(vhdl_texto, caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['harv_u'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[45:]
        self.gera_ini_map_generic(vhdl_texto[:15], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[16:], caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['interconnect'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[52:]
        self.gera_ini_map_generic(vhdl_texto[:9], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[10:], caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['axi4l_master'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[36:]
        self.gera_ini_map_no_generic(vhdl_texto, caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['axi4l_interconnect_4'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[53:]
        self.gera_ini_map_generic(vhdl_texto[:20], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[21:], caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['axi4l_rom'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[26:]
        self.gera_ini_map_generic(vhdl_texto[:17], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[18:], caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['uart'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[31:]
        self.gera_ini_map_generic(vhdl_texto[:12], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[13:], caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['axi4l_wdt_slave'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[31:]
        self.gera_ini_map_generic(vhdl_texto[:14], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[15:], caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['gpio'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[30:]
        self.gera_ini_map_generic(vhdl_texto[:14], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[15:], caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['acelerador'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[48:]
        self.gera_ini_map_generic(vhdl_texto[:16], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[17:], caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['memoria'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[26:]
        self.gera_ini_map_memory(vhdl_texto[:9], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[10:], caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['memoria'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[26:]
        self.gera_ini_map_memory(vhdl_texto[:9], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[10:], caminho_dir)

        self.criar_reset(config_axi)
        self.criar_processador(config_axi, config)
        self.criar_mem_interconnect(config_axi, config)
        self.criar_axi4l_master(config_axi, config)
        self.criar_axi4l_interconnect(config_axi, config)
        self.criar_axi4l_rom(config_axi, config)
        self.criar_uart(config_axi, config)
        self.criar_wdt(config_axi, config)
        self.criar_gpio(config_axi, config)
        self.criar_acelerador(config_axi, config)
        self.criar_memory(config_axi, config)
        self.criar_memory2(config_axi, config)

        self.verifica_ini(config_axi, config)

        self.vhdl_texto_aux = self.criador_lib(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_entidade(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_generic_2(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_portas(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_arq(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_constant(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_sinal(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_map(self.vhdl_texto_aux, config_axi)

        if arq_ext != None:
            if config['Acelerador']['check_customizavel'] == 'TRUE':
                config_ext = configparser.ConfigParser()
                config_ext.read(arq_ext)
                self.vhdl_texto_aux = self.criador_map_customizavel(self.vhdl_texto_aux, config_ext)

        self.vhdl_texto_aux = self.criador_ext(self.vhdl_texto_aux, config_axi)

        destino_arq = open(arq_vhd, 'w')
        destino_arq.write(self.vhdl_texto_aux)
        destino_arq.close()
