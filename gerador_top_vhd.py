import sys
import os
import configparser
import shutil

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
        texto += f"entity {config['Entidade']['nome']} is\n"
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

        nome8 = config['Generic']['nome8']
        valor8 = config['Generic']['valor8']
        type8 = config['Generic']['type8']

        config.remove_option('Generic','nome8')
        config.remove_option('Generic','type8')
        config.remove_option('Generic','valor8')

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
                        temp += f"{' '*2}constant {v:<21}:"
                texto += temp

        config['Generic']['nome8'] = nome8
        config['Generic']['type8'] = type8
        config['Generic']['valor8'] = valor8
        with open('barramento.ini', 'w') as configfile:
            config.write(configfile)
            
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
                        temp = f"{' '*2}signal {v:<21}  "
                texto += temp + "\n"
        texto += f"\nbegin \n"
        return texto

    def criador_map(self, texto, config, config_2): # Criação do Port Map do arquivo top
        temp = ""

        if config['Map 60']['check'] == 'FALSE':
            config.remove_section('Map 60')
        else:
            config.remove_option('Map 60','check')

        if config['Map 61']['check'] == 'FALSE':
            config.remove_section('Map 61')
        else:
            config.remove_option('Map 61','check')
        
        if config['Map 65']['check'] == 'FALSE':
            config.remove_section('Map 65')
        else:
            config.remove_option('Map 65','check')

        if config['Map 66']['check'] == 'FALSE':
            config.remove_section('Map 66')
        else:
            config.remove_option('Map 66','check')
        
        if config['Map 67']['check'] == 'FALSE':
            config.remove_section('Map 67')
        else:
            config.remove_option('Map 67','check')

        if config['Map 68']['check'] == 'FALSE':
            config.remove_section('Map 68')
        else:
            config.remove_option('Map 68','check')

        if config['Elif 69']['check'] == 'FALSE':
            config.remove_section('Elif 69')
            config.remove_section('Elif 70')
        else:
            config.remove_option('Elif 69','check')

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

    def criador_map_customizavel(self, texto, config, config_axi): # Criação do Port Map de arquivo externo
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
                        elif v == 'mestre':
                            temp += f"    {n:<18}  =>  {config_axi['Sinal 48']['nome']}, \n"
                        elif v == 'escravo':
                            temp += f"    {n:<18}  =>  {config_axi['Sinal 49']['nome']}, \n"
                        else:
                            temp += f"{' '*4}{n:<18}  =>  {v}, \n"
                texto += temp + "\n"
                temp = ""
                texto = texto[:-4] + "\n"
                texto += f"{' '*2});\n"
        return texto

    def criador_ext(self, texto, config): # Criar variaveis externas 
        enable_ecc = 'enable_dmem_g'
        disabled_ecc = 'disabled_dmem_g'
        enable_dmem_ecc_g = 'enable_dmem_ecc_g'
        enable_dmem = config['Generic']['nome4']
        enable_dmem_ecc = config['Generic']['nome5']

        temp = "\n"
        temp += f"{' '*2}{disabled_ecc} : if not {enable_dmem} generate\n"
        temp += f"{' '*2}begin\n"
        temp += f"{' '*4}{config['Sinal 19']['nome']} <= '0';\n"
        temp += f"{' '*4}{config['Sinal 20']['nome']} <= '1';\n"
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
                if aux == 'Elif 69':
                    texto += f"{' '*2}end generate;\n"
                    texto += f"{' '*2}{enable_dmem_ecc_g} : if {enable_dmem} and {enable_dmem_ecc} generate\n{' '*2}begin"
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

    def gera_ini_generic(self, vhdl_texto, config, caminho_dir, diretorio):
        self.contador = 0
        for linha in vhdl_texto:
            if linha[2:9] == 'generic':
                self.criar_ini += "[Generic]\n"
            else:
                self.temp = linha.find(':')
                self.ini = str(linha[:self.temp])
                self.fim = str(linha[self.temp:])
                if self.temp != -1:
                    #if self.fim[2:18] == 'std_logic_vector':
                    #    self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:18]}\nvector{self.contador} = {int(self.fim[19:21])+1}\nvalor{self.contador} = x{self.fim[37:45]}\n"
                    #    self.contador += 1
                    if self.ini[4:13] == 'GPIO_SIZE':
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:9]}\nvalor{self.contador} = {config['GPIO']['largura']}\n"
                        self.contador += 1
                    elif self.ini[4:12] == 'HARV_TMR':
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:9]}\nvalor{self.contador} = {config['Harv']['harv_tmr']}\n"
                        self.contador += 1
                    elif self.ini[4:12] == 'HARV_ECC':
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:9]}\nvalor{self.contador} = {config['Harv']['harv_ecc']}\n"
                        self.contador += 1
                    elif self.ini[4:18] == 'DMEM_BASE_ADDR':
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:18]}\nvector{self.contador} = {int(self.fim[19:21])+1}\nvalor{self.contador} = {config['Memoria']['endereco_memoria']}\n"
                        self.contador += 1
                    elif self.ini[4:18] == 'DMEM_HIGH_ADDR':
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:18]}\nvector{self.contador} = {int(self.fim[19:21])+1}\nvalor{self.contador} = {config['Memoria']['tamanho']}\n"
                        self.contador += 1
                    elif self.ini[4:22] == 'PROGRAM_START_ADDR':
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:18]}\nvector{self.contador} = {int(self.fim[19:21])+1}\nvalor{self.contador} = x70000000\n"
                        self.contador += 1
                    else:
                        self.criar_ini += f"nome{self.contador} = {self.ini[4:]}\ntype{self.contador} = {self.fim[2:9]}\nvalor{self.contador} = {self.fim[12:]}\n"
                        self.contador += 1

        self.criar_ini += "\n"
        self.criar_ini = self.criar_ini.replace(";", "")
        self.criar_ini = self.criar_ini.replace("  ", "")
        self.criar_ini = self.criar_ini.replace(":=", "")

        self.criar_ini += f"nome{self.contador} = BRAM_BASE_ADDR\ntype{self.contador} = std_logic_vector\nvector{self.contador} = 32\n"
        self.contador += 1
        self.criar_ini += f"nome{self.contador} = BRAM_HIGH_ADDR\ntype{self.contador} = std_logic_vector\nvector{self.contador} = 32\n"
        self.contador += 1
        self.criar_ini += f"nome{self.contador} = ENABLE_BRAM_ECC\ntype{self.contador} = boolean\n"
        self.contador += 1
        self.criar_ini += f"nome{self.contador} = IS_SIMULATION\ntype{self.contador} = boolean\nvalor{self.contador} = FALSE\n"
        self.contador += 1
        self.criar_ini += f'nome{self.contador} = AHX_FILEPATH\ntype{self.contador} = string\nvalor{self.contador} = "{diretorio}/SoC/sim/"\n'
        self.contador += 1
        #self.criar_ini += f"nome{self.contador} = MEH_BASE_ADDR\ntype{self.contador} = std_logic_vector\nvector{self.contador} = 32\n"
        #self.contador += 1
        #self.criar_ini += f"nome{self.contador} = MEH_HIGH_ADDR\ntype{self.contador} = std_logic_vector\nvector{self.contador} = 32\n"
        #self.contador += 1

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
                if linha[7:23] == "reset_controller" or linha[7:23] == "mem_interconnect" or linha[7:27] == "axi4l_interconnect_6" or linha[7:21] == "compressor_top" or linha[7:17] == "axi4l_bram" or linha[7:10] == "top":
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
                if linha[7:23] == "unaligned_memory" or linha[7:27] == "unaligned_ecc_memory" : 
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

    def gera_ini_bram(self, caminho_dir):
        self.criar_ini += f"[Sinal {self.contador}]\nnome: bram_master_w\ntype= axim\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: bram_slave_w\ntype= axis\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: bram_ev_rdata_valid_w\ntype= no vector\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: bram_ev_sb_error_w\ntype= no vector\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: bram_ev_db_error_w\ntype= no vector\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: bram_ev_error_addr_w\ntype= vector 32\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: bram_ev_ecc_addr_w\ntype= vector 32\n"
        self.contador +=1
        self.criar_ini += f"[Sinal {self.contador}]\nnome: bram_ev_enc_data_w\ntype= vector 39\n"
        self.contador +=1

        destino_arq = open(caminho_dir + '/barramento.ini', 'w')
        destino_arq.write(self.criar_ini)
        destino_arq.close()

    def criar_processador(self, config_axi, config):
        config_axi['Map 60']['check'] = config['Harv']['check_harv']
        config_axi['Map 60']['nome'] = str(config_axi['Map 60']['nome']).replace(" is","_u")
        config_axi['Map 60']['entity'] = str(config_axi['Map 60']['entity']).replace(" is","")
        config_axi['Map 60']['generic PROGRAM_START_ADDR'] = config_axi['Generic']['nome0']
        config_axi['Map 60']['generic TMR_CONTROL'] = config_axi['Generic']['nome1']
        config_axi['Map 60']['generic TMR_ALU'] = config_axi['Generic']['nome1']
        config_axi['Map 60']['generic ECC_REGFILE'] = config_axi['Generic']['nome2']
        config_axi['Map 60']['generic ECC_PC'] = config_axi['Generic']['nome2']
        config_axi['Map 60']['rstn_i'] = config_axi['Sinal 1']['nome']
        config_axi['Map 60']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 60']['start_i'] = config_axi['Porta 3']['nome']
        config_axi['Map 60']['poweron_rstn_i'] = config_axi['Porta 0']['nome']
        config_axi['Map 60']['wdt_rstn_i'] = config_axi['Sinal 3']['nome']
        config_axi['Map 60']['imem_rden_o'] = config_axi['Sinal 4']['nome']
        config_axi['Map 60']['imem_gnt_i'] = config_axi['Sinal 6']['nome']
        config_axi['Map 60']['imem_err_i'] = config_axi['Sinal 7']['nome']
        config_axi['Map 60']['imem_addr_o'] = config_axi['Sinal 5']['nome']
        config_axi['Map 60']['imem_rdata_i'] = config_axi['Sinal 8']['nome']
        #config_axi['Map 60']['hard_dmem_o'] = config_axi['Sinal 9']['nome']
        config_axi['Map 60']['dmem_wren_o'] = config_axi['Sinal 10']['nome']
        config_axi['Map 60']['dmem_rden_o'] = config_axi['Sinal 11']['nome']
        config_axi['Map 60']['dmem_gnt_i'] = config_axi['Sinal 12']['nome']
        config_axi['Map 60']['dmem_err_i'] = config_axi['Sinal 13']['nome']
        config_axi['Map 60']['dmem_addr_o'] = config_axi['Sinal 14']['nome']
        config_axi['Map 60']['dmem_wdata_o'] = config_axi['Sinal 15']['nome']
        config_axi['Map 60']['dmem_wstrb_o'] = config_axi['Sinal 16']['nome']
        config_axi['Map 60']['dmem_rdata_i'] = config_axi['Sinal 17']['nome']
        #config_axi['Map 60']['clr_ext_event_o'] = 'open'
        config_axi['Map 60']['ext_interrupt_i'] = 'x00'
        config_axi['Map 60']['ext_event_i'] = config_axi['Sinal 33']['nome']

        if config['Barramento']['check_timeout'] == 'FALSE':
            config_axi['Map 60']['periph_timeout_i'] = config_axi['Sinal 44']['nome']
        else:
            config_axi['Map 60']['periph_timeout_i'] = "'0'"

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_reset(self, config_axi):
        config_axi['Map 59']['nome'] = str(config_axi['Map 59']['nome']).replace(" is","_u")
        config_axi['Map 59']['entity'] = str(config_axi['Map 59']['entity']).replace(" is","")
        config_axi['Map 59']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 59']['poweron_rstn_i'] = config_axi['Porta 0']['nome']
        config_axi['Map 59']['btn_rstn_i'] = config_axi['Porta 1']['nome']
        config_axi['Map 59']['wdt_rstn_i'] = config_axi['Sinal 3']['nome']
        config_axi['Map 59']['periph_timeout_i'] = config_axi['Sinal 44']['nome']
        config_axi['Map 59']['ext_rstn_o'] = config_axi['Sinal 0']['nome']
        config_axi['Map 59']['proc_rstn_o'] = config_axi['Sinal 1']['nome']
        config_axi['Map 59']['periph_rstn_o'] = config_axi['Sinal 2']['nome']
        config_axi['Map 59']['ext_periph_rstn_o'] = config_axi['Porta 4']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_mem_interconnect(self, config_axi, config):
        config_axi['Map 61']['check'] = config['Harv']['check_harv']
        config_axi['Map 61']['nome'] = str(config_axi['Map 61']['nome']).replace(" is","_u")
        config_axi['Map 61']['entity'] = str(config_axi['Map 61']['entity']).replace(" is","")
        config_axi['Map 61']['generic mem0_base_addr'] = config_axi['Generic']['nome6']
        config_axi['Map 61']['generic mem0_high_addr'] = config_axi['Generic']['nome7']
        config_axi['Map 61']['imem_rden_i'] = config_axi['Sinal 4']['nome']
        config_axi['Map 61']['imem_addr_i'] = config_axi['Sinal 5']['nome']
        config_axi['Map 61']['imem_gnt_o'] = config_axi['Sinal 6']['nome']
        config_axi['Map 61']['imem_err_o'] = config_axi['Sinal 7']['nome']
        config_axi['Map 61']['imem_rdata_o'] = config_axi['Sinal 8']['nome']
        config_axi['Map 61']['dmem_wren_i'] = config_axi['Sinal 10']['nome']
        config_axi['Map 61']['dmem_rden_i'] = config_axi['Sinal 11']['nome']
        config_axi['Map 61']['dmem_gnt_o'] = config_axi['Sinal 12']['nome']
        config_axi['Map 61']['dmem_err_o'] = config_axi['Sinal 13']['nome']
        config_axi['Map 61']['dmem_addr_i'] = config_axi['Sinal 14']['nome']
        config_axi['Map 61']['dmem_wdata_i'] = config_axi['Sinal 15']['nome']
        config_axi['Map 61']['dmem_wstrb_i'] = config_axi['Sinal 16']['nome']
        config_axi['Map 61']['dmem_rdata_o'] = config_axi['Sinal 17']['nome']
        config_axi['Map 61']['mem0_wren_o'] = config_axi['Sinal 18']['nome']
        config_axi['Map 61']['mem0_rden_o'] = config_axi['Sinal 19']['nome']
        config_axi['Map 61']['mem0_gnt_i'] = config_axi['Sinal 20']['nome']
        config_axi['Map 61']['mem0_err_i'] = config_axi['Sinal 21']['nome']
        config_axi['Map 61']['mem0_prot_o'] = config_axi['Sinal 22']['nome']
        config_axi['Map 61']['mem0_addr_o'] = config_axi['Sinal 23']['nome']
        config_axi['Map 61']['mem0_wdata_o'] = config_axi['Sinal 24']['nome']
        config_axi['Map 61']['mem0_wstrb_o'] = config_axi['Sinal 25']['nome']
        config_axi['Map 61']['mem0_rdata_i'] = config_axi['Sinal 26']['nome']
        config_axi['Map 61']['mem1_wren_o'] = config_axi['Sinal 35']['nome']
        config_axi['Map 61']['mem1_rden_o'] = config_axi['Sinal 36']['nome']
        config_axi['Map 61']['mem1_gnt_i'] = config_axi['Sinal 37']['nome']
        config_axi['Map 61']['mem1_err_i'] = config_axi['Sinal 38']['nome']
        config_axi['Map 61']['mem1_prot_o'] = config_axi['Sinal 39']['nome']
        config_axi['Map 61']['mem1_addr_o'] = config_axi['Sinal 40']['nome']
        config_axi['Map 61']['mem1_wdata_o'] = config_axi['Sinal 41']['nome']
        config_axi['Map 61']['mem1_wstrb_o'] = config_axi['Sinal 42']['nome']
        config_axi['Map 61']['mem1_rdata_i'] = config_axi['Sinal 43']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_axi4l_master(self, config_axi, config):
        config_axi['Map 62']['nome'] = str(config_axi['Map 62']['nome']).replace(" is","_u")
        config_axi['Map 62']['entity'] = str(config_axi['Map 62']['entity']).replace(" is","")
        config_axi['Map 62']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 62']['wren_i'] = config_axi['Sinal 35']['nome']
        config_axi['Map 62']['rden_i'] = config_axi['Sinal 36']['nome']
        config_axi['Map 62']['gnt_o'] = config_axi['Sinal 37']['nome']
        config_axi['Map 62']['err_o'] = config_axi['Sinal 38']['nome']
        config_axi['Map 62']['prot_i'] = config_axi['Sinal 39']['nome']
        config_axi['Map 62']['addr_i'] = config_axi['Sinal 40']['nome']
        config_axi['Map 62']['wdata_i'] = config_axi['Sinal 41']['nome']
        config_axi['Map 62']['wstrb_i'] = config_axi['Sinal 42']['nome']
        config_axi['Map 62']['rdata_o'] = config_axi['Sinal 43']['nome']
        config_axi['Map 62']['master_o'] = config_axi['Sinal 45']['nome']
        config_axi['Map 62']['slave_i'] = config_axi['Sinal 46']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 62']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 62']['rstn_i'] = config_axi['Sinal 2']['nome']

        if config['Barramento']['check_timeout'] == 'FALSE':
            config_axi['Map 62']['timeout_o'] = config_axi['Sinal 44']['nome']
        else:
            config_axi['Map 62']['timeout_o'] = 'open'

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_axi4l_interconnect(self, config_axi, config):
        config_axi['Map 63']['nome'] = str(config_axi['Map 63']['nome']).replace(" is","_u")
        config_axi['Map 63']['entity'] = str(config_axi['Map 63']['entity']).replace(" is","")
        config_axi['Map 63']['generic slave0_base_addr'] = config['Barramento']['endereco']
        config_axi['Map 63']['generic slave0_high_addr'] = 'x00000FFF'
        config_axi['Map 63']['generic slave1_base_addr'] = config['UART']['endereco']
        config_axi['Map 63']['generic slave1_high_addr'] = 'x8000001F'
        config_axi['Map 63']['generic slave2_base_addr'] = 'x80000100'
        config_axi['Map 63']['generic slave2_high_addr'] = 'x80000103'
        config_axi['Map 63']['generic slave3_base_addr'] = config['GPIO']['tamanho']
        config_axi['Map 63']['generic slave3_high_addr'] = 'x80000207'
        config_axi['Map 63']['generic slave4_base_addr'] = 'x80000300'
        config_axi['Map 63']['generic slave4_high_addr'] = 'x80000303'
        config_axi['Map 63']['generic slave5_base_addr'] = 'x80000400'
        config_axi['Map 63']['generic slave5_high_addr'] = 'x80000403'
        config_axi['Map 63']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 63']['master_i'] = config_axi['Sinal 45']['nome']
        config_axi['Map 63']['slave_o'] = config_axi['Sinal 46']['nome']
        config_axi['Map 63']['master0_o'] = config_axi['Sinal 47']['nome']
        config_axi['Map 63']['slave0_i'] = config_axi['Sinal 48']['nome']

        if config['UART']['check_uart'] == 'TRUE':
            config_axi['Map 63']['master1_o'] = config_axi['Sinal 49']['nome']
            config_axi['Map 63']['slave1_i'] = config_axi['Sinal 50']['nome']
        else:
            config_axi['Map 63']['master1_o'] = 'open'
            config_axi['Map 63']['slave1_i'] = 'AXI4L_S2M_DECERR'

        if config['Barramento']['check_wdt'] == 'TRUE':
            config_axi['Map 63']['master2_o'] = config_axi['Sinal 51']['nome']
            config_axi['Map 63']['slave2_i'] = config_axi['Sinal 52']['nome']
        else:
            config_axi['Map 63']['master2_o'] = 'open'
            config_axi['Map 63']['slave2_i'] = 'AXI4L_S2M_DECERR'
        
        if config['GPIO']['check_gpio'] == 'TRUE':
            config_axi['Map 63']['master3_o'] = config_axi['Sinal 53']['nome']
            config_axi['Map 63']['slave3_i'] = config_axi['Sinal 54']['nome']
        else:
            config_axi['Map 63']['master3_o'] = 'open'
            config_axi['Map 63']['slave3_i'] = 'AXI4L_S2M_DECERR'

        if config['Acelerador']['check_hsi'] == 'TRUE':
            config_axi['Map 63']['master4_o'] = config_axi['Sinal 55']['nome']
            config_axi['Map 63']['slave4_i'] = config_axi['Sinal 56']['nome']
        else:
            config_axi['Map 63']['master4_o'] = 'open'
            config_axi['Map 63']['slave4_i'] = 'AXI4L_S2M_DECERR'

        if config['Acelerador']['check_customizavel'] == 'TRUE':
            config_axi['Map 63']['master5_o'] = config_axi['Sinal 57']['nome']
            config_axi['Map 63']['slave5_i'] = config_axi['Sinal 58']['nome']
        else:
            config_axi['Map 63']['master5_o'] = 'open'
            config_axi['Map 63']['slave5_i'] = 'AXI4L_S2M_DECERR'

        config_axi['Map 63']['ext_master_o'] = config_axi['Porta 12']['nome']
        config_axi['Map 63']['ext_slave_i'] = config_axi['Porta 13']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 63']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 63']['rstn_i'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_axi4l_rom(self, config_axi, config):
        config_axi['Map 64']['nome'] = str(config_axi['Map 64']['nome']).replace(" is","_u")
        config_axi['Map 64']['entity'] = str(config_axi['Map 64']['entity']).replace(" is","")
        config_axi['Map 64']['generic base_addr'] = config['Barramento']['endereco']
        config_axi['Map 64']['generic high_addr'] = 'x00000FFF'
        config_axi['Map 64']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 64']['master_i'] = config_axi['Sinal 47']['nome']
        config_axi['Map 64']['slave_o'] = config_axi['Sinal 48']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 64']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 64']['rstn_i'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_uart(self, config_axi, config):
        config_axi['Map 65']['check'] = config['UART']['check_uart']
        config_axi['Map 65']['nome'] = str(config_axi['Map 65']['nome']).replace(" is","_u")
        config_axi['Map 65']['entity'] = str(config_axi['Map 65']['entity']).replace(" is","")
        config_axi['Map 65']['generic base_addr'] = config['UART']['endereco']
        config_axi['Map 65']['generic high_addr'] = 'x8000001F'
        config_axi['Map 65']['generic rx_fifo_size'] = config['UART']['profundidade_fifo']
        config_axi['Map 65']['master_i'] = config_axi['Sinal 49']['nome']
        config_axi['Map 65']['slave_o'] = config_axi['Sinal 50']['nome']
        config_axi['Map 65']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 65']['uart_rx_i'] = config_axi['Porta 5']['nome']
        config_axi['Map 65']['uart_tx_o'] = config_axi['Porta 6']['nome']
        config_axi['Map 65']['uart_cts_i'] = config_axi['Porta 7']['nome']
        config_axi['Map 65']['uart_rts_o'] = config_axi['Porta 8']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 65']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 65']['rstn_i'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_wdt(self, config_axi, config):
        config_axi['Map 66']['check'] = config['Barramento']['check_wdt']
        config_axi['Map 66']['nome'] = str(config_axi['Map 66']['nome']).replace(" is","_u")
        config_axi['Map 66']['entity'] = str(config_axi['Map 66']['entity']).replace(" is","")
        config_axi['Map 66']['generic base_addr'] = 'x80000100'
        config_axi['Map 66']['generic high_addr'] = 'x80000103'
        config_axi['Map 66']['master_i'] = config_axi['Sinal 51']['nome']
        config_axi['Map 66']['slave_o'] = config_axi['Sinal 52']['nome']
        config_axi['Map 66']['ext_rstn_i'] = config_axi['Sinal 0']['nome']
        config_axi['Map 66']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 66']['wdt_rstn_o'] = config_axi['Sinal 3']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 66']['periph_rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 66']['periph_rstn_i'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_gpio(self, config_axi, config):
        config_axi['Map 67']['check'] = config['GPIO']['check_gpio']
        config_axi['Map 67']['nome'] = str(config_axi['Map 67']['nome']).replace(" is","_u")
        config_axi['Map 67']['entity'] = str(config_axi['Map 67']['entity']).replace(" is","")
        config_axi['Map 67']['generic base_addr'] = config['GPIO']['tamanho']
        config_axi['Map 67']['generic high_addr'] = 'x80000207'
        config_axi['Map 67']['generic gpio_size'] = config_axi['Generic']['nome8']
        config_axi['Map 67']['master_i'] = config_axi['Sinal 53']['nome']
        config_axi['Map 67']['slave_o'] = config_axi['Sinal 54']['nome']
        config_axi['Map 67']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 67']['tri_o'] = config_axi['Porta 9']['nome']
        config_axi['Map 67']['rports_i'] = config_axi['Porta 10']['nome']
        config_axi['Map 67']['wports_o'] = config_axi['Porta 11']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 67']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 67']['rstn_i'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_acelerador(self, config_axi, config):
        config_axi['Map 68']['check'] = config['Acelerador']['check_hsi']
        config_axi['Map 68']['nome'] = str(config_axi['Map 68']['nome']).replace(" is","_u")
        config_axi['Map 68']['entity'] = str(config_axi['Map 68']['entity']).replace(" is","")
        #config_axi['Map 68']['generic c_s00_axi_data_width'] = '32'
        #config_axi['Map 68']['generic c_s00_axi_addr_width'] = '4'
        config_axi['Map 68']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 68']['awvalid'] = 'axi_slave4_master_w.awvalid'
        config_axi['Map 68']['wvalid'] = 'axi_slave4_master_w.wvalid'
        config_axi['Map 68']['bvalid'] = 'axi_slave4_slave_w.bvalid'
        config_axi['Map 68']['arvalid'] = 'axi_slave4_master_w.arvalid'
        config_axi['Map 68']['rvalid'] = 'axi_slave4_slave_w.rvalid'
        config_axi['Map 68']['awready'] = 'axi_slave4_slave_w.awready'
        config_axi['Map 68']['wready'] = 'axi_slave4_slave_w.wready'
        config_axi['Map 68']['bready'] = 'axi_slave4_master_w.bready'
        config_axi['Map 68']['arready'] = 'axi_slave4_slave_w.arready'
        config_axi['Map 68']['rready'] = 'axi_slave4_master_w.rready'
        config_axi['Map 68']['awaddr'] = 'axi_slave4_master_w.awaddr'
        config_axi['Map 68']['awprot'] = 'axi_slave4_master_w.awprot'
        config_axi['Map 68']['wdata'] = 'axi_slave4_master_w.wdata'
        config_axi['Map 68']['wstrb'] = 'axi_slave4_master_w.wstrb'
        config_axi['Map 68']['bresp'] = 'axi_slave4_slave_w.bresp'
        config_axi['Map 68']['araddr'] = 'axi_slave4_master_w.araddr'
        config_axi['Map 68']['arprot'] = 'axi_slave4_master_w.arprot'
        config_axi['Map 68']['rdata'] = 'axi_slave4_slave_w.rdata'
        config_axi['Map 68']['rresp'] = 'axi_slave4_slave_w.rresp'

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Map 68']['aresetn'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Map 68']['aresetn'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_memory(self, config_axi, config):
        config_axi['Elif 69']['check'] = config['Memoria']['check_memoria']
        config_axi['Elif 69']['nome'] = str(config_axi['Elif 69']['nome']).replace(" is","_u")
        config_axi['Elif 69']['entity'] = str(config_axi['Elif 69']['entity']).replace(" is","")
        config_axi['Elif 69']['generic base_addr'] = config_axi['Generic']['nome6']
        config_axi['Elif 69']['generic high_addr'] = config_axi['Generic']['nome7']
        config_axi['Elif 69']['generic sim_init_ahx'] = 'FALSE'
        config_axi['Elif 69']['generic ahx_filepath'] = config_axi['Generic']['nome13']
        config_axi['Elif 69']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Elif 69']['s_wr_ready_o'] = 'open'
        config_axi['Elif 69']['s_rd_ready_o'] = 'open'
        config_axi['Elif 69']['s_wr_en_i'] = config_axi['Sinal 18']['nome']
        config_axi['Elif 69']['s_rd_en_i'] = config_axi['Sinal 19']['nome']
        config_axi['Elif 69']['s_done_o'] = config_axi['Sinal 20']['nome']
        config_axi['Elif 69']['s_error_o'] = config_axi['Sinal 21']['nome']
        config_axi['Elif 69']['s_addr_i'] = config_axi['Sinal 23']['nome']
        config_axi['Elif 69']['s_wdata_i'] = config_axi['Sinal 24']['nome']
        config_axi['Elif 69']['s_wstrb_i'] = config_axi['Sinal 25']['nome']
        config_axi['Elif 69']['s_rdata_o'] = config_axi['Sinal 26']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Elif 69']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Elif 69']['rstn_i'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_memory2(self, config_axi, config):
        config_axi['Elif 70']['nome'] = str(config_axi['Elif 70']['nome']).replace("unaligned_ecc_memory is","unaligned_ecc_memory_u")
        config_axi['Elif 70']['entity'] = str(config_axi['Elif 70']['entity']).replace("unaligned_ecc_memory is","unaligned_ecc_memory")
        config_axi['Elif 70']['generic base_addr'] = config_axi['Generic']['nome6']
        config_axi['Elif 70']['generic high_addr'] = config_axi['Generic']['nome7']
        config_axi['Elif 70']['generic sim_init_ahx'] = 'FALSE'
        config_axi['Elif 70']['generic ahx_filepath'] = config_axi['Generic']['nome13']
        config_axi['Elif 70']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Elif 70']['correct_error_i'] = config_axi['Sinal 9']['nome']
        config_axi['Elif 70']['s_wr_ready_o'] = 'open'
        config_axi['Elif 70']['s_rd_ready_o'] = 'open'
        config_axi['Elif 70']['s_wr_en_i'] = config_axi['Sinal 18']['nome']
        config_axi['Elif 70']['s_rd_en_i'] = config_axi['Sinal 19']['nome']
        config_axi['Elif 70']['s_done_o'] = config_axi['Sinal 20']['nome']
        config_axi['Elif 70']['s_error_o'] = config_axi['Sinal 21']['nome']
        config_axi['Elif 70']['s_addr_i'] = config_axi['Sinal 23']['nome']
        config_axi['Elif 70']['s_wdata_i'] = config_axi['Sinal 24']['nome']
        config_axi['Elif 70']['s_wstrb_i'] = config_axi['Sinal 25']['nome']
        config_axi['Elif 70']['s_rdata_o'] = config_axi['Sinal 26']['nome']
        config_axi['Elif 70']['ev_rdata_valid_o'] = config_axi['Sinal 27']['nome']
        config_axi['Elif 70']['ev_sb_error_o'] = config_axi['Sinal 28']['nome']
        config_axi['Elif 70']['ev_db_error_o'] = config_axi['Sinal 29']['nome']
        config_axi['Elif 70']['ev_error_addr_o'] = config_axi['Sinal 30']['nome']
        config_axi['Elif 70']['ev_ecc_addr_o'] = config_axi['Sinal 31']['nome']
        config_axi['Elif 70']['ev_enc_data_o'] = config_axi['Sinal 32']['nome']

        if config['Barramento']['reset'] == 'Padrão':
            config_axi['Elif 70']['rstn_i'] = config_axi['Porta 0']['nome']
        else:
            config_axi['Elif 70']['rstn_i'] = config_axi['Sinal 2']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def criar_bram(self, config_axi, config):
        config_axi['Map 71']['nome'] = str(config_axi['Map 71']['nome']).replace(" is","_u")
        config_axi['Map 71']['entity'] = str(config_axi['Map 71']['entity']).replace(" is","")
        config_axi['Map 71']['generic base_addr'] = config_axi['Generic']['nome9']
        config_axi['Map 71']['generic high_addr'] = config_axi['Generic']['nome10']
        config_axi['Map 71']['generic ecc'] = config_axi['Generic']['nome11']
        config_axi['Map 71']['generic sim_init_ahx'] = config_axi['Generic']['nome12']
        config_axi['Map 71']['generic ahx_filepath'] = config_axi['Generic']['nome13']
        config_axi['Map 71']['rstn_i'] = config_axi['Sinal 2']['nome']
        config_axi['Map 71']['clk_i'] = config_axi['Porta 2']['nome']
        config_axi['Map 71']['master_i'] = config_axi['Sinal 72']['nome']
        config_axi['Map 71']['correct_error_i'] = config_axi['Sinal 9']['nome']
        config_axi['Map 71']['slave_o'] = config_axi['Sinal 73']['nome']
        config_axi['Map 71']['ev_rdata_valid_o'] = config_axi['Sinal 74']['nome']
        config_axi['Map 71']['ev_sb_error_o'] = config_axi['Sinal 75']['nome']
        config_axi['Map 71']['ev_db_error_o'] = config_axi['Sinal 76']['nome']
        config_axi['Map 71']['ev_error_addr_o'] = config_axi['Sinal 77']['nome']
        config_axi['Map 71']['ev_ecc_addr_o'] = config_axi['Sinal 78']['nome']
        config_axi['Map 71']['ev_enc_data_o'] = config_axi['Sinal 79']['nome']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def verifica_ini(self, config_axi, config):
        config_axi['Entidade']['nome'] = 'top'
        config_axi['Generic']['valor1'] = config['Harv']['harv_tmr']
        config_axi['Generic']['valor2'] = config['Harv']['harv_ecc']
        config_axi['Generic']['valor8'] = config['GPIO']['largura']
        config_axi['Map 67']['generic base_addr'] = config['GPIO']['tamanho']
        config_axi['Generic']['valor6'] = config['Memoria']['endereco_memoria']
        config_axi['Generic']['valor7'] = config['Memoria']['tamanho']
        config_axi['Map 65']['generic rx_fifo_size'] = config['UART']['profundidade_fifo']
        config_axi['Map 65']['generic base_addr'] = config['UART']['endereco']
        config_axi['Map 64']['generic base_addr'] = config['Barramento']['endereco']

        with open('barramento.ini', 'w') as configfile:
            config_axi.write(configfile)

    def ajusta_arq_zed(self, diretorio, vhdl_texto, caminho_dir, config_axi):
        arq_zed = open(diretorio + 'fpga/zedboard/hdl/zed_top.vhd', 'r')
        vhdl_zed = arq_zed.readlines()
        arq_zed.close()

        del vhdl_zed[60:]

        arq_zed = open(diretorio + 'fpga/zedboard/hdl/zed_top.vhd', 'w')
        arq_zed.writelines(vhdl_zed)
        arq_zed.close()

        self.criar_ini = ''
        vhdl_texto.clear()
        top_vhd = open(diretorio + "hdl/top.vhd", 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[48:]
        self.gera_ini_map_generic(vhdl_texto[:29], caminho_dir + "/arquivos_topo/")
        self.gera_ini_map_no_generic(vhdl_texto[30:], caminho_dir + "/arquivos_topo/")

        config_top = configparser.ConfigParser()
        config_top.read(caminho_dir + "/arquivos_topo/barramento.ini")

        self.vhdl_texto_aux = ''
        self.criar_top(config_top, config_axi, caminho_dir + "/arquivos_topo/")
        self.vhdl_texto_aux = self.criador_map_customizavel(self.vhdl_texto_aux, config_top, config_axi)

        vhdl_txt = ''
        arq_zed = open(diretorio + 'fpga/zedboard/hdl/zed_top.vhd', 'r')
        vhdl_txt = arq_zed.read()
        arq_zed.close()

        arq_zed = open(diretorio + 'fpga/zedboard/hdl/zed_top.vhd', 'w')
        arq_zed.write(vhdl_txt + self.vhdl_texto_aux + "\nend arch;\n")
        arq_zed.close()

    def criar_top(self, config_top, config_axi, diretorio):
        config_top['Map 80']['nome'] = str(config_top['Map 80']['nome']).replace(" is","_u")
        config_top['Map 80']['entity'] = str(config_top['Map 80']['entity']).replace(" is","")
        config_top['Map 80']['generic program_start_addr'] = config_axi['Generic']['valor0']
        config_top['Map 80']['generic harv_tmr'] = config_axi['Generic']['valor1']
        config_top['Map 80']['generic harv_ecc'] = config_axi['Generic']['valor2']
        config_top['Map 80']['generic enable_rom'] = config_axi['Generic']['valor3']
        config_top['Map 80']['generic enable_dmem'] = config_axi['Generic']['valor4']
        config_top['Map 80']['generic enable_dmem_ecc'] = config_axi['Generic']['valor5']
        config_top['Map 80']['generic dmem_base_addr'] = config_axi['Generic']['valor6']
        config_top['Map 80']['generic dmem_high_addr'] = config_axi['Generic']['valor7']
        config_top['Map 80']['generic gpio_size'] = config_axi['Generic']['valor8']
        config_top['Map 80']['generic bram_base_addr'] = 'x70000000'
        config_top['Map 80']['generic bram_high_addr'] = 'x70007FFF'
        config_top['Map 80']['generic enable_bram_ecc'] = 'FALSE'
        config_top['Map 80']['generic is_simulation'] = config_axi['Generic']['valor12']
        config_top['Map 80']['generic ahx_filepath'] = config_axi['Generic']['valor13']
        config_top['Map 80']['poweron_rstn_i'] = 'rstn_w'
        config_top['Map 80']['btn_rstn_i'] = 'btn_rst_i'
        config_top['Map 80']['clk_i'] = 'clk50_w'
        config_top['Map 80']['start_i'] = 'rstn_w'
        config_top['Map 80']['periph_rstn_o'] = 'periph_rstn_w'
        config_top['Map 80']['uart_rx_i'] = 'uart_rx_i'
        config_top['Map 80']['uart_tx_o'] = 'uart_tx_o'
        config_top['Map 80']['uart_cts_i'] = 'uart_cts_i'
        config_top['Map 80']['uart_rts_o'] = 'uart_rts_o'
        config_top['Map 80']['gpio_tri_o'] = 'gpio_tri_w'
        config_top['Map 80']['gpio_rd_i'] = 'gpio_rd_w'
        config_top['Map 80']['gpio_wr_o'] = 'gpio_wr_w'
        config_top['Map 80']['axi4l_master_o'] = 'open'
        config_top['Map 80']['axi4l_slave_i'] = 'AXI4L_S2M_DECERR'
        config_top['Map 80']['ext_event_i'] = "'0'"

        with open(diretorio + 'barramento.ini', 'w') as configfile:
            config_top.write(configfile)

    def pesquisar(self, lista, pasta):
        for i in range(len(lista)):
            if lista[i] == pasta:
                return True
        return False

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

        del vhdl_texto[116:]
        del vhdl_axi[:65]
        del vhdl_axi[26:]

        self.gera_ini_library(vhdl_texto[:13], caminho_dir)
        self.gera_ini_generic(vhdl_texto[13:27], config, caminho_dir, arq_vhd)
        self.gera_ini_port(vhdl_texto[28:57], caminho_dir)
        self.gera_ini_signal(vhdl_texto[57:], caminho_dir)
        self.gera_ini_signal_bus(vhdl_axi, caminho_dir)
        #self.gera_ini_signal_manual(caminho_dir)

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
        top_vhd = open(caminho_dir + config_path['Path']['axi4l_interconnect_6'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[59:]
        self.gera_ini_map_generic(vhdl_texto[:22], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[23:], caminho_dir)

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
        #del vhdl_texto[48:]
        del vhdl_texto[30:]
        #self.gera_ini_map_generic(vhdl_texto[:16], caminho_dir)
        #self.gera_ini_map_no_generic(vhdl_texto[17:], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto, caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['memoria'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[31:]
        self.gera_ini_map_memory(vhdl_texto[:14], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[15:], caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['memoria2'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[43:]
        self.gera_ini_map_memory(vhdl_texto[:14], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[15:], caminho_dir)

        vhdl_texto.clear()
        top_vhd = open(caminho_dir + config_path['Path']['bram'], 'r')
        vhdl_texto = top_vhd.readlines()
        top_vhd.close()
        del vhdl_texto[39:]
        self.gera_ini_map_generic(vhdl_texto[:17], caminho_dir)
        self.gera_ini_map_no_generic(vhdl_texto[18:], caminho_dir)

        self.gera_ini_bram(caminho_dir)

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
        self.criar_bram(config_axi, config)
        self.criar_memory(config_axi, config)
        self.criar_memory2(config_axi, config)

        self.verifica_ini(config_axi, config)

        self.vhdl_texto_aux = self.criador_lib(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_entidade(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_generic(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_portas(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_arq(self.vhdl_texto_aux, config_axi)
        #self.vhdl_texto_aux = self.criador_constant(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_sinal(self.vhdl_texto_aux, config_axi)
        self.vhdl_texto_aux = self.criador_map(self.vhdl_texto_aux, config_axi, config)

        if arq_ext != None:
            if config['Acelerador']['check_customizavel'] == 'TRUE':
                config_ext = configparser.ConfigParser()
                config_ext.read(arq_ext)
                self.vhdl_texto_aux = self.criador_map_customizavel(self.vhdl_texto_aux, config_ext, config_axi)
                aux1 = config_ext['Map']['generic base']
                aux2 = config_ext['Map']['generic high']
                self.vhdl_texto_aux = self.vhdl_texto_aux.replace('x"80000400"', f'{aux1[:1]}"{aux1[1:]}"')
                self.vhdl_texto_aux = self.vhdl_texto_aux.replace('x"80000403"', f'{aux2[:1]}"{aux2[1:]}"')

        self.vhdl_texto_aux = self.criador_ext(self.vhdl_texto_aux, config_axi)

        lista = os.listdir(arq_vhd)
        diretorio = os.path.join(arq_vhd, 'SoC') + os.path.sep
        # se diretorio existe
        if os.path.isdir(diretorio):
            # TODO: Adicionar prompt para confirmar antes de deletar pasta
            # apaga diretorio
            shutil.rmtree(diretorio)

        diretorio_script = os.path.join(diretorio, 'script')
        diretorio_sim = os.path.join(diretorio, 'sim')
        diretorio_hdl = os.path.join(diretorio, 'hdl')
        os.makedirs(diretorio)
        os.makedirs(diretorio_script)
        os.makedirs(diretorio_sim)
        os.makedirs(diretorio_hdl)
        shutil.copytree('harv-soc', os.path.join(diretorio, 'harv-soc'), dirs_exist_ok = True)
        shutil.copytree('compressor_axi', os.path.join(diretorio, 'compressor'), dirs_exist_ok = True)
        shutil.copytree('arquivos_topo/fpga', os.path.join(diretorio, 'fpga'), dirs_exist_ok = True)
        shutil.copy('arquivos_topo/vivado-ahx-sim.tcl', diretorio_script)
        shutil.copy('arquivos_topo/vivado-open-static-simulation.tcl', diretorio_script)
        shutil.copy('arquivos_topo/top_tb.vhd', diretorio_sim)
        shutil.copy('arquivos_topo/top_tb_behav.wcfg', diretorio_sim)
        shutil.copy('arquivos_topo/Makefile', diretorio)
        diretorio_software = os.path.join(diretorio, 'software')

        if config['Software']['check_software'] == 'TRUE':
            shutil.copytree(config['Software']['caminho'], diretorio_software, dirs_exist_ok = True)

        destino_arq = open(os.path.join(diretorio, "hdl", "top.vhd"), 'w')
        destino_arq.write(self.vhdl_texto_aux)
        destino_arq.close()
        
        self.ajusta_arq_zed(diretorio, vhdl_texto, caminho_dir, config_axi)

        arq_ahx = open(os.path.join(diretorio, 'sim', 'top_tb.vhd'), 'r')
        vhdl_ahx = arq_ahx.read()
        arq_ahx.close()
        vhdl_ahx = vhdl_ahx.replace("../../../../../src/helloworld/out/app-sim.ahx", f"{diretorio}software/out/app-sim.ahx")
        arq_ahx = open(diretorio + 'sim/ahx_tb.vhd', 'w')
        arq_ahx.write(vhdl_ahx)
        arq_ahx.close()
