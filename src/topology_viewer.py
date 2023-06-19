import sys
import json
from PyQt5.QtWidgets import QApplication, QGraphicsScene, QGraphicsView, QGraphicsEllipseItem, QGraphicsLineItem, QGraphicsSimpleTextItem, QGraphicsRectItem
from PyQt5.QtCore import Qt, QRectF

'''
This classDraggableEllipseItem extends QGraphicsEllipseItem. 
This class enables dragging functionality by setting the ItemIsMovable flag and handling the ItemPositionChange event.
In the itemChange method of DraggableEllipseItem, we ensure that the ellipse remains within the boundaries of the scene. 
If the new position is outside the scene's boundaries, we restrict it to the nearest valid position.
'''


class DraggableEllipseItem(QGraphicsEllipseItem):
    def __init__(self, x, y, width, height):
        super().__init__(x, y, width, height)
        self.setFlag(QGraphicsEllipseItem.ItemIsMovable, True)
        self.setFlag(QGraphicsEllipseItem.ItemSendsScenePositionChanges, True)
    
    def itemChange(self, change, value):
        if change == QGraphicsEllipseItem.ItemPositionChange:
            # Ensure the ellipse remains within the scene boundaries
            scene = self.scene()
            if scene is not None:
                scene_rect = scene.sceneRect()
                new_rect = QRectF(value.x(), value.y(), self.rect().width(), self.rect().height())
                if not scene_rect.contains(new_rect):
                    value.setX(min(max(value.x(), scene_rect.left()), scene_rect.right() - self.rect().width()))
                    value.setY(min(max(value.y(), scene_rect.top()), scene_rect.bottom() - self.rect().height()))
        
        return super().itemChange(change, value)


class DraggableRectangleItem(QGraphicsRectItem):
    def __init__(self, x, y, width, height):
        super().__init__(x, y, width, height)
        self.setFlag(QGraphicsRectItem.ItemIsMovable, True)
        self.setFlag(QGraphicsRectItem.ItemSendsScenePositionChanges, True)
    
    def itemChange(self, change, value):
        if change == QGraphicsRectItem.ItemPositionChange:
            # Ensure the rectangle remains within the scene boundaries
            scene = self.scene()
            if scene is not None:
                scene_rect = scene.sceneRect()
                new_rect = QRectF(value.x(), value.y(), self.rect().width(), self.rect().height())
                if not scene_rect.contains(new_rect):
                    value.setX(min(max(value.x(), scene_rect.left()), scene_rect.right() - self.rect().width()))
                    value.setY(min(max(value.y(), scene_rect.top()), scene_rect.bottom() - self.rect().height()))
        
        return super().itemChange(change, value)
    

'''
We define a TopologyViewer class that inherits from QGraphicsView. 
It handles reading the JSON file, creating the topology based on the data, and displaying it using PyQt5.
'''
    
class TopologyViewer(QGraphicsView):
    def __init__(self, file_path):
        super().__init__()
        self.setWindowTitle("Topology")
        self.scene = QGraphicsScene()
        self.setScene(self.scene)
        self.show()
        
        areas, technologies = self.read_json_file(file_path)
        self.create_topology(areas, technologies)
    
    '''
    Define a function to read the JSON file and extract the data
    '''
    def read_json_file(self, file_path):
        with open(file_path) as json_file:
            data = json.load(json_file)
            return data['Areas'], data['Techs']
    
    '''
    Define a function which iterates over the areas, 
    creates QGraphicsEllipseItem objects for each area's coordinates, and adds them to the scene. 
    It also connects the areas with QGraphicsLineItem objects based on their coordinates.
    '''
    
    
    def create_topology(self, areas, technologies):
        node_size = 50  # Adjust the size of the area nodes
        tech_size = 100  # Adjust the size of the technology boxes
        spacing = 20  # Adjust the spacing between area nodes and technology boxes
    
        # Create area nodes
        for area, coordinates in areas.items():
            lat = coordinates.get('lat', 0)
            lon = coordinates.get('lon', 0)
            ellipse = DraggableEllipseItem(-node_size/2, -node_size/2, node_size, node_size)  # Adjust size as needed
            ellipse.setBrush(Qt.red)  # Adjust color as needed
            ellipse.setPos(lat - node_size/2, lon - node_size/2)  # Position the node correctly, This ensures that the center of each node is placed at the specified latitude and longitude coordinates.
            ellipse.setAcceptHoverEvents(True)
            ellipse.setFlag(QGraphicsEllipseItem.ItemIsSelectable, True)
            ellipse.setData(0, area)  # Store area name as data for later reference
            self.scene.addItem(ellipse)
    
            text_item = QGraphicsSimpleTextItem(area, parent=ellipse)
            text_item.setBrush(Qt.white)
            text_item.setPos(-text_item.boundingRect().width() / 2, -text_item.boundingRect().height() / 2)
    
        # Create technology boxes and links
        for area, techs in technologies.items():
            area_node = next((item for item in self.scene.items() if isinstance(item, DraggableEllipseItem) and item.data(0) == area), None)
            if area_node:
                y_offset = node_size / 2 + spacing  # Adjust the vertical offset
                for i, tech in enumerate(techs):
                    tech_box = DraggableRectangleItem(-tech_size / 2, -tech_size / 2, tech_size, tech_size)  # Adjust size as needed #added
                    #tech_box = QGraphicsRectItem(-tech_size / 2, -tech_size / 2, tech_size, tech_size)
                    tech_box.setBrush(Qt.blue)  # Adjust color as needed
                    tech_box.setPos(area_node.x() + node_size/2, area_node.y() + y_offset)
                    tech_box.setAcceptHoverEvents(True)#added
                    tech_box.setFlag(QGraphicsRectItem.ItemIsSelectable, True) #added
                    tech_box.setData(0, techs)  # Store technology name as data for later reference #added
                    self.scene.addItem(tech_box)
                    
                    text_item = QGraphicsSimpleTextItem(tech, parent=tech_box)
                    text_item.setBrush(Qt.white)
                    text_item.setPos(-text_item.boundingRect().width() / 2, -text_item.boundingRect().height() / 2)

                    #link = QGraphicsLineItem(area_node.x(), area_node.y(), tech_box.x() + tech_size/2, tech_box.y() + tech_size/2)
                    #self.scene.addItem(link)

                    y_offset += tech_size + spacing


        # Adjust the scene rect to fit all items
        #self.scene.setSceneRect(self.scene.itemsBoundingRect()) ##This will resize the scene automatically to encompass all the nodes and lines.
        self.scene.setSceneRect(-500, -500, 1000, 1000) 



def main():
    app = QApplication(sys.argv)
    file_path = '/Users/shwetat/Projects/FLEX4FACT/frameworkDevelopment_repo/cleanexportinterface/TestData/Default/test1.json'  # Replace with your JSON file path
    viewer = TopologyViewer(file_path)
    sys.exit(app.exec_())

if __name__ == '__main__':
    main()



