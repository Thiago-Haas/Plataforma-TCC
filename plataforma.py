# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'plataforma.ui'
#
# Created by: PyQt5 UI code generator 5.15.6
#
# WARNING: Any manual changes made to this file will be lost when pyuic5 is
# run again.  Do not edit this file unless you know what you are doing.

import os
from PyQt5 import QtCore, QtGui, QtWidgets
from PyQt5.QtWidgets import QFileDialog, QMessageBox
from processador import Ui_Processador
from barramento import Ui_Barramento
from perifericos import Ui_Perifericos
from software import Ui_Software
from gerador_top_vhd import Gerador_Vhdl

class Ui_Plataforma(object):
    def __init__(self):
        self.path = None
        self.nome_arq = None

    def openProcessador(self):
        self.window = QtWidgets.QMainWindow()
        self.ui = Ui_Processador()
        self.ui.setupUi(self.window)
        self.window.show()

    def openBarramento(self):
        self.window = QtWidgets.QMainWindow()
        self.ui = Ui_Barramento()
        self.ui.setupUi(self.window)
        self.window.show()

    def openPerifericos(self):
        self.window = QtWidgets.QMainWindow()
        self.ui = Ui_Perifericos()
        self.ui.setupUi(self.window)
        self.window.show()

    def openSoftware(self):
        self.window = QtWidgets.QMainWindow()
        self.ui = Ui_Software()
        self.ui.setupUi(self.window)
        self.window.show()
    
    def openLoad(self):
        nomeload = QFileDialog.getOpenFileName(None, 'Open a File', '', 'Ini(*.ini)')
        self.path = nomeload[0]

    def msgButtonClick(self, i):
        return i.text()

    def gerar_vhdl(self, Plataforma):
        caminho_arq = sys.argv[0]
        caminho_arq = os.path.abspath(caminho_arq)
        caminho_dir = os.path.dirname(caminho_arq)
        
        if not self.path:
            nomesave = QFileDialog.getSaveFileName(None, 'Save a File', '', 'Vhd(*.vhd)')
            self.nome_arq = nomesave[0] + '.vhd'
            self.vhdl = Gerador_Vhdl()
            self.vhdl.gera_vhdl(self.nome_arq[24:31], caminho_dir + '/config.ini', None)
        else:
            nomesave = QFileDialog.getSaveFileName(None, 'Save a File', '', 'Vhd(*.vhd)')
            self.nome_arq = nomesave[0] + '.vhd'
            self.vhdl = Gerador_Vhdl()
            self.vhdl.gera_vhdl(self.nome_arq[24:31], caminho_dir + '/config.ini', self.path)

        msgBox = QMessageBox()
        msgBox.setIcon(QMessageBox.Information)
        msgBox.setText("Arquivo VHDL salvo em: /SoC/" + self.nome_arq[24:31])
        msgBox.setWindowTitle("Aviso")
        msgBox.setStandardButtons(QMessageBox.Ok)
        msgBox.buttonClicked.connect(self.msgButtonClick)

        returnValue = msgBox.exec()
        if returnValue == QMessageBox.Ok:
            print('Finalizado com sucesso!')

        Plataforma.close()

    def setupUi(self, Plataforma):
        Plataforma.setObjectName("Plataforma")
        Plataforma.resize(509, 313)
        self.centralwidget = QtWidgets.QWidget(Plataforma)
        self.centralwidget.setObjectName("centralwidget")
        self.Processador = QtWidgets.QPushButton(self.centralwidget, clicked = lambda: self.openProcessador())
        self.Processador.setGeometry(QtCore.QRect(10, 10, 221, 71))
        self.Processador.setObjectName("Processador")
        self.Barramento = QtWidgets.QPushButton(self.centralwidget, clicked = lambda: self.openBarramento())
        self.Barramento.setGeometry(QtCore.QRect(10, 90, 221, 71))
        self.Barramento.setObjectName("Barramento")
        self.Perifericos = QtWidgets.QPushButton(self.centralwidget, clicked = lambda: self.openPerifericos())
        self.Perifericos.setGeometry(QtCore.QRect(270, 90, 221, 71))
        self.Perifericos.setObjectName("Perifericos")
        self.Software = QtWidgets.QPushButton(self.centralwidget, clicked = lambda: self.openSoftware())
        self.Software.setGeometry(QtCore.QRect(270, 10, 221, 71))
        self.Software.setObjectName("Software")
        self.save_load = QtWidgets.QPushButton(self.centralwidget, clicked = lambda: self.openLoad())
        self.save_load.setGeometry(QtCore.QRect(10, 170, 221, 71))
        self.save_load.setObjectName("save_load")
        self.Sair = QtWidgets.QPushButton(self.centralwidget, clicked = lambda: self.gerar_vhdl(Plataforma))
        self.Sair.setGeometry(QtCore.QRect(270, 170, 221, 71))
        self.Sair.setObjectName("Sair")
        self.label = QtWidgets.QLabel(self.centralwidget)
        self.label.setGeometry(QtCore.QRect(40, 250, 431, 17))
        font = QtGui.QFont()
        font.setPointSize(12)
        self.label.setFont(font)
        self.label.setObjectName("label")
        Plataforma.setCentralWidget(self.centralwidget)
        self.menubar = QtWidgets.QMenuBar(Plataforma)
        self.menubar.setGeometry(QtCore.QRect(0, 0, 509, 22))
        self.menubar.setObjectName("menubar")
        Plataforma.setMenuBar(self.menubar)
        self.statusbar = QtWidgets.QStatusBar(Plataforma)
        self.statusbar.setObjectName("statusbar")
        Plataforma.setStatusBar(self.statusbar)

        self.retranslateUi(Plataforma)
        QtCore.QMetaObject.connectSlotsByName(Plataforma)

    def retranslateUi(self, Plataforma):
        _translate = QtCore.QCoreApplication.translate
        Plataforma.setWindowTitle(_translate("Plataforma", "Plataforma"))
        self.Processador.setText(_translate("Plataforma", "Configurações do Processador"))
        self.Barramento.setText(_translate("Plataforma", "Configurações do Barramento"))
        self.Perifericos.setText(_translate("Plataforma", "Configurações dos Periféricos"))
        self.Software.setText(_translate("Plataforma", "Configurações do Software"))
        self.save_load.setText(_translate("Plataforma", "Carregar Arquivo"))
        self.Sair.setText(_translate("Plataforma", "Gerar Vhdl"))
        self.label.setText(_translate("Plataforma", "As configurações estão sendo salvas no arquivo \"config.ini\" "))


if __name__ == "__main__":
    import sys
    app = QtWidgets.QApplication(sys.argv)
    Plataforma = QtWidgets.QMainWindow()
    ui = Ui_Plataforma()
    ui.setupUi(Plataforma)
    Plataforma.show()
    sys.exit(app.exec_())
