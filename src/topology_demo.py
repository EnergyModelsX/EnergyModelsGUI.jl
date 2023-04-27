''' 
This script creates a GUI application using PyQt5, it  a popular Python library for creating desktop applications 
with a graphical user interface (GUI). This script creates an interactive topology viewer app that displays nodes
in a graphical view, each of which is a clickable element that displays a dialog window when clicked.
'''

import sys
import json
from PyQt5 import QtCore
from PyQt5.QtCore import Qt, QRectF
from PyQt5.QtGui import QPainter
from PyQt5.QtWidgets import QApplication, QMainWindow, QGraphicsScene, QGraphicsView, QGraphicsItem, QGraphicsTextItem, QMenu, QAction, QMessageBox, QDialog, QVBoxLayout, QHBoxLayout, QLineEdit, QTextEdit, QPushButton, QLabel

# Define the JSON files, currently I am hard coding jason file here. Later we will read the case files from a directory.
json_files = {
  "node1": {
    "name": "Node 1",
    "description": "ELNode1",
    "x": -100,
    "y": -100
  },
  "node2": {
    "name": "Node 2",
    "description": "ELNode2",
    "x": 100,
    "y": 100
  }
}


# Define a custom QGraphicsItem for the nodes in the topology
class NodeItem(QGraphicsItem):
  '''
  This is a custom class that defines a QGraphicsItem for the nodes in the topology.
  It inherits from QGraphicsItem and overrides various methods to define its appearance and behavior.
  '''
  def __init__(self, name, x, y):
    super().__init__()
    self.name = name
    self.x = x
    self.y = y
    self.setFlag(QGraphicsItem.ItemIsMovable)
    self.setFlag(QGraphicsItem.ItemIsSelectable)

  def boundingRect(self):
    '''
    Method defines the rectangle that encloses the node.
    '''
    return QRectF(-25, -25, 50, 50)

  def paint(self, painter, option, widget):
    '''
    The paint method defines how the node is drawn.
    '''
    painter.setBrush(Qt.green)
    painter.drawEllipse(-25, -25, 50, 50)
    painter.drawText(-20, -20, self.name)

  def contextMenuEvent(self, event):
    '''
    This method is called when the node is right-clicked and displays a context menu with an "Edit" action
    '''
    menu = QMenu()
    edit_action = QAction("Edit", menu)
    edit_action.triggered.connect(self.edit)
    menu.addAction(edit_action)
    menu.exec(event.screenPos())

  def edit(self):
    '''
    This method is called when the "Edit" action is triggered and displays a dialog window for editing the node's name and description.
    '''
    # Open a dialog to edit the corresponding JSON data
    dialog = NodeDialog(json_files[self.name])
    if dialog.exec_() == QDialog.Accepted:
      # Update the node name and description
      json_files[self.name]["name"] = dialog.name
      json_files[self.name]["description"] = dialog.description
      # Redraw the node with the updated name
      self.name = json_files[self.name]["name"]
      self.prepareGeometryChange()
      self.update()


# Define a custom dialog for editing node data
class NodeDialog(QDialog):
  '''
  This is a custom dialog window that is displayed when a node is edited. 
  It contains a QLineEdit and a QTextEdit widget for editing the node's name and description,
  as well as "Save" and "Cancel" buttons.
  '''
  def __init__(self, node_data, parent=None):
    super().__init__(parent)
    self.setWindowTitle("Edit Node")
    self.setModal(True)
    self.name = QLineEdit(node_data["name"])
    self.description = QTextEdit(node_data["description"])
    save_button = QPushButton("Save")
    save_button.clicked.connect(self.accept)
    cancel_button = QPushButton("Cancel")
    cancel_button.clicked.connect(self.reject)
    button_layout = QHBoxLayout()
    button_layout.addWidget(save_button)
    button_layout.addWidget(cancel_button)
    layout = QVBoxLayout()
    layout.addWidget(QLabel("Name:"))
    layout.addWidget(self.name)
    layout.addWidget(QLabel("Description:"))
    layout.addWidget(self.description)
    layout.addLayout(button_layout)
    self.setLayout(layout)


# Define the main window for the app
class MainWindow(QMainWindow):
  '''
  This is the main window for the app. It inherits from QMainWindow and defines the layout and behavior of the app.
  It creates a QGraphicsScene and a QGraphicsView to display the topology, and adds nodes to the scene using the NodeItem class. 
  It also sets the render hint to enable antialiasing in the QGraphicsView widget. 
  Finally, it creates an instance of QApplication, sets the MainWindow as the central widget, and shows the main window.
  '''
  def __init__(self):
    super().__init__()
    self.setWindowTitle("Topology Viewer")
    self.scene = QGraphicsScene()
    self.view = QGraphicsView(self.scene)
    self.view.setRenderHint(QPainter.Antialiasing)
    self.setCentralWidget(self.view)
    self.nodes = {}
    for name, data in json_files.items():
      node = NodeItem(data["name"], data.get("x", 0), data.get("y", 0))
      node.name = name # set the name attribute to match the key in the json_files dictionary
      self.scene.addItem(node)
      self.nodes[name] = node
      self.view.setSceneRect(self.scene.itemsBoundingRect())
      self.view.centerOn(0, 0)


      

app = QApplication(sys.argv) #creates an instance of QApplication, which manages the GUI application's control flow and main settings
main_window = MainWindow()
main_window.show()
sys.exit(app.exec_()) #this starts the main loop for the app and waits for events. 


