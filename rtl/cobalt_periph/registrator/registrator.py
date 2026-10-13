#!/usr/bin/env python3

import html
import json
import subprocess
import sys
from pathlib import Path

import hjson
from PySide6.QtCore import Qt
from PySide6.QtGui import QTextDocument
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QDialog, QFileDialog,
    QVBoxLayout, QHBoxLayout, QFormLayout, QSplitter, QTreeWidget,
    QTreeWidgetItem, QLabel, QPushButton, QLineEdit, QComboBox,
    QSpinBox, QTextEdit, QMessageBox, QGroupBox, QTableWidget,
    QTableWidgetItem, QHeaderView, QMenu
)


def text_value(value, default=""):
    return str(value) if value is not None else default


class CreateBlockDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Create Register Block")
        self.setMinimumWidth(480)

        layout = QVBoxLayout(self)
        form = QFormLayout()

        self.name = QLineEdit("SYSCTRL")
        self.directory = QLineEdit(str(Path.cwd()))
        browse = QPushButton("Browse...")
        browse.clicked.connect(self.choose_directory)

        directory_row = QHBoxLayout()
        directory_row.addWidget(self.directory, 1)
        directory_row.addWidget(browse)

        self.regwidth = QComboBox()
        self.regwidth.addItems(["32", "64"])

        self.clock = QLineEdit("clk_i")
        self.reset = QLineEdit("rst_ni")

        form.addRow("Block name:", self.name)
        form.addRow("Save directory:", directory_row)
        form.addRow("Register width:", self.regwidth)
        form.addRow("Primary clock:", self.clock)
        form.addRow("Primary reset:", self.reset)
        layout.addLayout(form)

        buttons = QHBoxLayout()
        create = QPushButton("Create")
        cancel = QPushButton("Cancel")
        create.clicked.connect(self.accept)
        cancel.clicked.connect(self.reject)
        buttons.addStretch()
        buttons.addWidget(cancel)
        buttons.addWidget(create)
        layout.addLayout(buttons)

    def choose_directory(self):
        directory = QFileDialog.getExistingDirectory(
            self, "Choose output directory", self.directory.text()
        )
        if directory:
            self.directory.setText(directory)

    def get_data(self):
        return {
            "name": self.name.text().strip(),
            "directory": self.directory.text().strip(),
            "regwidth": self.regwidth.currentText(),
            "clock_primary": self.clock.text().strip(),
            "reset_primary": self.reset.text().strip(),
        }


class RegisterDialog(QDialog):
    def __init__(self, register=None, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Register Properties")
        self.setMinimumWidth(420)

        register = register or {}
        layout = QVBoxLayout(self)
        form = QFormLayout()

        self.name = QLineEdit(text_value(register.get("name")))
        self.desc = QLineEdit(text_value(register.get("desc")))
        self.swaccess = QComboBox()
        self.swaccess.addItems(["rw", "ro", "wo", "rw1c", "rw1s"])
        current_access = text_value(register.get("swaccess"), "rw")
        if self.swaccess.findText(current_access) < 0:
            self.swaccess.addItem(current_access)
        self.swaccess.setCurrentText(current_access)
        self.resval = QLineEdit(text_value(register.get("resval"), "0"))

        form.addRow("Register name:", self.name)
        form.addRow("Description:", self.desc)
        form.addRow("Software access:", self.swaccess)
        form.addRow("Reset value:", self.resval)
        layout.addLayout(form)

        buttons = QHBoxLayout()
        save = QPushButton("OK")
        cancel = QPushButton("Cancel")
        save.clicked.connect(self.accept)
        cancel.clicked.connect(self.reject)
        buttons.addStretch()
        buttons.addWidget(cancel)
        buttons.addWidget(save)
        layout.addLayout(buttons)

    def get_data(self):
        return {
            "name": self.name.text().strip(),
            "desc": self.desc.text().strip(),
            "swaccess": self.swaccess.currentText(),
            "resval": self.resval.text().strip(),
        }


class FieldDialog(QDialog):
    def __init__(self, field=None, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Field Properties")
        self.setMinimumWidth(420)

        field = field or {}
        layout = QVBoxLayout(self)
        form = QFormLayout()

        self.name = QLineEdit(text_value(field.get("name")))
        self.bits = QLineEdit(text_value(field.get("bits"), "31:0"))
        self.desc = QLineEdit(text_value(field.get("desc")))
        self.swaccess = QComboBox()
        self.swaccess.addItems(["rw", "ro", "wo", "rw1c", "rw1s"])
        current_access = text_value(field.get("swaccess"), "")
        if current_access:
            if self.swaccess.findText(current_access) < 0:
                self.swaccess.addItem(current_access)
            self.swaccess.setCurrentText(current_access)

        form.addRow("Field name:", self.name)
        form.addRow("Bits (e.g. 7:0):", self.bits)
        form.addRow("Description:", self.desc)
        form.addRow("Software access (optional):", self.swaccess)
        layout.addLayout(form)

        buttons = QHBoxLayout()
        save = QPushButton("OK")
        cancel = QPushButton("Cancel")
        save.clicked.connect(self.accept)
        cancel.clicked.connect(self.reject)
        buttons.addStretch()
        buttons.addWidget(cancel)
        buttons.addWidget(save)
        layout.addLayout(buttons)

    def get_data(self):
        result = {
            "bits": self.bits.text().strip(),
            "name": self.name.text().strip(),
            "desc": self.desc.text().strip(),
        }
        if self.swaccess.currentText():
            result["swaccess"] = self.swaccess.currentText()
        return result


class RegGenWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Cobalt RegGen")
        self.resize(1250, 800)

        self.data = None
        self.current_file = None
        self.dirty = False

        self.create_menu()
        self.create_interface()
        self.setStyleSheet("""
            QMainWindow, QWidget {
                background: #20242c;
                color: #e5e9f0;
            }
            QMenuBar, QMenu, QStatusBar {
                background: #171a20;
            }
            QLineEdit, QComboBox, QSpinBox, QTextEdit, QTreeWidget {
                background: #171a20;
                color: #e5e9f0;
                border: 1px solid #39414f;
                padding: 5px;
            }
            QPushButton {
                background: #356ac3;
                border: none;
                border-radius: 4px;
                padding: 8px;
            }
            QPushButton:hover {
                background: #477dd6;
            }
            QGroupBox {
                border: 1px solid #39414f;
                margin-top: 8px;
                padding: 8px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 8px;
            }
        """)
        self.statusBar().showMessage("Ready — open or create a register block")

    def create_menu(self):
        file_menu = self.menuBar().addMenu("&File")

        new_action = file_menu.addAction("New Register Block...")
        new_action.setShortcut("Ctrl+N")
        new_action.triggered.connect(self.new_block)

        open_action = file_menu.addAction("Open HJSON...")
        open_action.setShortcut("Ctrl+O")
        open_action.triggered.connect(self.open_hjson)

        self.save_action = file_menu.addAction("Save")
        self.save_action.setShortcut("Ctrl+S")
        self.save_action.triggered.connect(self.save_hjson)

        file_menu.addSeparator()
        exit_action = file_menu.addAction("Exit")
        exit_action.triggered.connect(self.close)

        help_menu = self.menuBar().addMenu("&Help")

    def create_interface(self):
        root = QWidget()
        main_layout = QVBoxLayout(root)

        toolbar = QHBoxLayout()

        # File actions — left side
        for label, callback in [
            ("New Block", self.new_block),
            ("Open HJSON", self.open_hjson),
            ("Save", self.save_hjson),
        ]:
            button = QPushButton(label)
            button.clicked.connect(callback)
            toolbar.addWidget(button)

        # Push the tool actions to the right
        toolbar.addStretch()

        # Check button
        self.check_button = QPushButton("CHECK")
        self.check_button.clicked.connect(self.check_block)
        toolbar.addWidget(self.check_button)

        # Export dropdown button
        self.export_button = QPushButton("EXPORT ▼")
        self.export_menu = QMenu(self)

        export_rtl_action = self.export_menu.addAction("Export RTL")
        export_doc_action = self.export_menu.addAction("Export DOC")
        export_ral_action = self.export_menu.addAction("Export RAL")


        self.export_actions = [
            export_rtl_action,
            export_doc_action,
            export_ral_action,
        ]

        for action in self.export_actions:
            action.setEnabled(False)

        export_rtl_action.triggered.connect(
            lambda: self.export_block("RTL")
        )
        export_doc_action.triggered.connect(
            lambda: self.export_block("DOC")
        )
        export_ral_action.triggered.connect(
            lambda: self.export_block("RAL")
        )

        self.export_button.setMenu(self.export_menu)
        toolbar.addWidget(self.export_button)

        main_layout.addLayout(toolbar)

        splitter = QSplitter(Qt.Orientation.Horizontal)

        left = QWidget()
        left_layout = QVBoxLayout(left)
        left_layout.addWidget(QLabel("REGISTER MAP"))

        self.project_label = QLabel("No file loaded")
        self.project_label.setWordWrap(True)
        left_layout.addWidget(self.project_label)

        self.tree = QTreeWidget()
        self.tree.setHeaderLabels(["Name", "Type"])
        self.tree.itemDoubleClicked.connect(self.edit_selected)
        left_layout.addWidget(self.tree, 1)

        tree_buttons = QHBoxLayout()
        for label, callback in [
            ("+ Register", self.add_register),
            ("+ Field", self.add_field),
            ("Edit", self.edit_selected),
            ("Remove", self.remove_selected),
        ]:
            button = QPushButton(label)
            button.clicked.connect(callback)
            tree_buttons.addWidget(button)
        left_layout.addLayout(tree_buttons)

        splitter.addWidget(left)

        right = QWidget()
        right_layout = QVBoxLayout(right)

        metadata_group = QGroupBox("Register Block")
        metadata_form = QFormLayout(metadata_group)

        self.block_name = QLineEdit()
        self.regwidth = QComboBox()
        self.regwidth.addItems(["32", "64"])
        self.clock = QLineEdit()
        self.reset = QLineEdit()

        metadata_form.addRow("Name:", self.block_name)
        metadata_form.addRow("Register width:", self.regwidth)
        metadata_form.addRow("Primary clock:", self.clock)
        metadata_form.addRow("Primary reset:", self.reset)
        right_layout.addWidget(metadata_group)

        self.block_name.editingFinished.connect(self.metadata_changed)
        self.regwidth.currentTextChanged.connect(self.metadata_changed)
        self.clock.editingFinished.connect(self.metadata_changed)
        self.reset.editingFinished.connect(self.metadata_changed)

        help_text = QLabel(
            "Select a register or field in the tree. Double-click to edit it.\n"
            "Use + Register to add a register and + Field to add a field "
            "to the selected register."
        )
        help_text.setWordWrap(True)
        right_layout.addWidget(help_text)

        right_layout.addWidget(QLabel("REGISTER MAP"))
        
        self.register_table = QTableWidget()
        self.register_table.setColumnCount(7)
        self.register_table.setHorizontalHeaderLabels([
            "Register",
            "Field",
            "Bits",
            "Occupied",
            "SW Access",
            "Reset",
            "Description",
        ])
        # Make the table readable when cells are not selected
        self.register_table.setStyleSheet("""
            QTableWidget {
                background-color: #252526;
                color: #E0E0E0;
                gridline-color: #454545;
                selection-background-color: #264F78;
                selection-color: #FFFFFF;
                alternate-background-color: #2D2D30;
            }

            QTableWidget::item {
                background-color: #252526;
                color: #E0E0E0;
                padding: 4px;
            }

            QTableWidget::item:selected {
                background-color: #264F78;
                color: #FFFFFF;
            }

            QHeaderView::section {
                background-color: #333337;
                color: #FFFFFF;
                padding: 6px;
                border: 1px solid #454545;
            }
        """)        
        self.register_table.setAlternatingRowColors(True)
        self.register_table.setEditTriggers(
            QTableWidget.EditTrigger.NoEditTriggers
        )
        self.register_table.setEditTriggers(
            QTableWidget.EditTrigger.NoEditTriggers
        )
        self.register_table.setSelectionBehavior(
            QTableWidget.SelectionBehavior.SelectRows
        )
        self.register_table.setSelectionMode(
            QTableWidget.SelectionMode.SingleSelection
        )
        self.register_table.setAlternatingRowColors(True)
        self.register_table.setSortingEnabled(False)
        
        header = self.register_table.horizontalHeader()
        header.setSectionResizeMode(
            QHeaderView.ResizeMode.ResizeToContents
        )
        header.setStretchLastSection(True)
        
        right_layout.addWidget(self.register_table, 1)

        splitter.addWidget(right)
        splitter.setSizes([430, 820])
        main_layout.addWidget(splitter, 1)

        main_layout.addWidget(QLabel("OUTPUT / LOG"))
        self.log = QTextEdit()
        self.log.setReadOnly(True)
        self.log.setMaximumHeight(100)
        main_layout.addWidget(self.log)

        self.setCentralWidget(root)
        self.set_editor_enabled(False)

    def set_editor_enabled(self, enabled):
        for widget in [
            self.tree, self.block_name, self.regwidth,
            self.clock, self.reset
        ]:
            widget.setEnabled(enabled)

    def log_message(self, message, color=None):
        if color:
            self.log.append(
                f'<span style="color: {color};">{message}</span>'
            )
        else:
            self.log.append(message)

    def confirm_discard(self):
        if not self.dirty:
            return True
        answer = QMessageBox.question(
            self,
            "Unsaved changes",
            "Save changes before continuing?",
            QMessageBox.StandardButton.Save
            | QMessageBox.StandardButton.Discard
            | QMessageBox.StandardButton.Cancel,
        )
        if answer == QMessageBox.StandardButton.Save:
            return self.save_hjson()
        if answer == QMessageBox.StandardButton.Discard:
            return True
        return False

    def new_block(self):
        if not self.confirm_discard():
            return

        dialog = CreateBlockDialog(self)
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return

        values = dialog.get_data()
        if not all(values[k] for k in [
            "name", "directory", "clock_primary", "reset_primary"
        ]):
            QMessageBox.warning(
                self, "Missing information",
                "Fill in the block name, directory, clock and reset."
            )
            return

        if not values["name"].replace("_", "").isalnum():
            QMessageBox.warning(
                self, "Invalid name",
                "Use letters, digits and underscores in the block name."
            )
            return

        directory = Path(values["directory"]).expanduser()
        if not directory.is_dir():
            QMessageBox.warning(
                self, "Invalid directory",
                "Choose an existing directory."
            )
            return

        self.current_file = directory / f'{values["name"]}.hjson'
        self.data = {
            "name": values["name"],
            "regwidth": values["regwidth"],
            "clock_primary": values["clock_primary"],
            "reset_primary": values["reset_primary"],
            "bus_interfaces": [
                {"protocol": "reg_iface", "direction": "device"}
            ],
            "registers": [],
        }

        self.dirty = True
        self.sync_metadata()
        self.refresh_tree()
        self.set_editor_enabled(True)
        self.project_label.setText(str(self.current_file))
        self.log_message(f"Created new block: {values['name']}")
        self.save_hjson()

    def open_hjson(self):
        if not self.confirm_discard():
            return

        filename, _ = QFileDialog.getOpenFileName(
            self, "Open register-block HJSON", str(Path.cwd()),
            "HJSON files (*.hjson *.json);;All files (*)"
        )
        if not filename:
            return

        try:
            with open(filename, "r", encoding="utf-8") as stream:
                loaded = hjson.load(stream)

            if not isinstance(loaded, dict):
                raise ValueError("The file's top level must be an object.")

            if not isinstance(loaded.get("registers", []), list):
                raise ValueError("'registers' must be a list.")

            loaded.setdefault("registers", [])
            loaded.setdefault("bus_interfaces", [
                {"protocol": "reg_iface", "direction": "device"}
            ])

            for register in loaded["registers"]:
                if not isinstance(register, dict):
                    raise ValueError("Every register must be an object.")
                register.setdefault("fields", [])

            self.data = loaded
            self.current_file = Path(filename)
            self.dirty = False
            self.sync_metadata()
            self.refresh_tree()
            self.set_editor_enabled(True)
            self.project_label.setText(str(self.current_file))
            self.log_message(f"Opened: {filename}")
            self.statusBar().showMessage("HJSON loaded")
        except Exception as error:
            QMessageBox.critical(
                self, "Cannot open HJSON", str(error)
            )

    def sync_metadata(self):
        if not self.data:
            return

        self.block_name.blockSignals(True)
        self.regwidth.blockSignals(True)
        self.clock.blockSignals(True)
        self.reset.blockSignals(True)

        self.block_name.setText(text_value(self.data.get("name")))
        width = text_value(self.data.get("regwidth"), "32")
        if self.regwidth.findText(width) < 0:
            self.regwidth.addItem(width)
        self.regwidth.setCurrentText(width)
        self.clock.setText(text_value(self.data.get("clock_primary")))
        self.reset.setText(text_value(self.data.get("reset_primary")))

        self.block_name.blockSignals(False)
        self.regwidth.blockSignals(False)
        self.clock.blockSignals(False)
        self.reset.blockSignals(False)
        self.update_preview()

    def metadata_changed(self, *_):
        if not self.data:
            return
        self.data["name"] = self.block_name.text().strip()
        self.data["regwidth"] = self.regwidth.currentText()
        self.data["clock_primary"] = self.clock.text().strip()
        self.data["reset_primary"] = self.reset.text().strip()
        self.mark_dirty()

    def mark_dirty(self):
        for action in getattr(self, "export_actions", []):
            action.setEnabled(False)        
        self.dirty = True
        self.update_preview()
        if self.current_file:
            self.statusBar().showMessage(
                f"Unsaved changes — {self.current_file.name}"
            )

    def update_preview(self):
        self.register_table.setRowCount(0)

        if self.data is None:
            return

        rows = []

        for register in self.data.get("registers", []):
            fields = register.get("fields", [])

            if not fields:
                rows.append((register, None, 0))
            else:
                for field_index, field in enumerate(fields):
                    rows.append((register, field, field_index))

        self.register_table.setRowCount(len(rows))

        for row_index, (register, field, field_index) in enumerate(rows):

            # Register without any fields
            if field is None:
                values = [
                    register.get("name", ""),
                    "(no fields)",
                    "—",
                    "0",
                    register.get("swaccess", ""),
                    register.get("resval", ""),
                    register.get("desc", ""),
                ]

            # Register with fields
            else:
                bit_range = str(field.get("bits", ""))
                occupied = self.field_width(bit_range)

                values = [
                    register.get("name", "") if field_index == 0 else "",
                    field.get("name", ""),
                    bit_range,
                    str(occupied) if occupied is not None else "Invalid",
                    field.get(
                        "swaccess",
                        register.get("swaccess", "")
                    ),
                    register.get("resval", ""),
                    field.get("desc", ""),
                ]

            for column, value in enumerate(values):
                item = QTableWidgetItem(str(value))
                self.register_table.setItem(row_index, column, item)

        self.register_table.resizeRowsToContents()

    @staticmethod
    def field_width(bit_range):
        try:
            bit_range = bit_range.strip()

            if ":" in bit_range:
                high, low = map(int, bit_range.split(":"))
            else:
                high = low = int(bit_range)

            if low < 0 or high < low:
                return None

            return high - low + 1

        except (ValueError, AttributeError):
            return None

    def refresh_tree(self):
        self.tree.clear()
        if not self.data:
            return

        block = QTreeWidgetItem([
            text_value(self.data.get("name"), "Unnamed"),
            "Block",
        ])
        self.tree.addTopLevelItem(block)

        for register in self.data.get("registers", []):
            reg_item = QTreeWidgetItem([
                text_value(register.get("name"), "Unnamed"),
                "Register",
            ])
            block.addChild(reg_item)

            for field in register.get("fields", []):
                field_item = QTreeWidgetItem([
                    text_value(field.get("name"), "Unnamed"),
                    f"Field [{text_value(field.get('bits'))}]",
                ])
                reg_item.addChild(field_item)

        block.setExpanded(True)
        self.tree.expandAll()

    def selected_register_index(self):
        item = self.tree.currentItem()
        if item is None:
            return None

        if item.text(1).startswith("Field"):
            item = item.parent()

        if item is None or item.text(1) != "Register":
            return None

        parent = item.parent()
        return parent.indexOfChild(item) if parent else None

    def add_register(self):
        if not self.data:
            return

        dialog = RegisterDialog(parent=self)
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return

        register = dialog.get_data()
        if not register["name"]:
            QMessageBox.warning(self, "Missing name", "Enter a register name.")
            return

        register["fields"] = []
        self.data["registers"].append(register)
        self.mark_dirty()
        self.refresh_tree()
        self.log_message(f"Added register: {register['name']}")

    def add_field(self):
        if not self.data:
            return

        index = self.selected_register_index()
        if index is None:
            QMessageBox.information(
                self, "Select a register",
                "Select a register in the tree before adding a field."
            )
            return

        dialog = FieldDialog(parent=self)
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return

        field = dialog.get_data()
        if not field["name"] or not field["bits"]:
            QMessageBox.warning(
                self, "Missing information",
                "Enter a field name and bit range."
            )
            return

        self.data["registers"][index].setdefault("fields", []).append(field)
        self.mark_dirty()
        self.refresh_tree()
        self.log_message(
            f"Added field {field['name']} to "
            f"{self.data['registers'][index]['name']}"
        )

    def edit_selected(self, *_):
        if not self.data:
            return

        item = self.tree.currentItem()
        if item is None:
            return

        if item.text(1) == "Register":
            index = self.selected_register_index()
            if index is None:
                return
            register = self.data["registers"][index]
            dialog = RegisterDialog(register, self)
            if dialog.exec() != QDialog.DialogCode.Accepted:
                return

            updated = dialog.get_data()
            if not updated["name"]:
                QMessageBox.warning(self, "Missing name", "Enter a register name.")
                return
            updated["fields"] = register.get("fields", [])
            self.data["registers"][index] = updated

        elif item.text(1).startswith("Field"):
            index = self.selected_register_index()
            if index is None:
                return
            register = self.data["registers"][index]
            field_index = item.parent().indexOfChild(item)
            dialog = FieldDialog(register["fields"][field_index], self)
            if dialog.exec() != QDialog.DialogCode.Accepted:
                return
            updated = dialog.get_data()
            if not updated["name"] or not updated["bits"]:
                QMessageBox.warning(
                    self, "Missing information",
                    "Enter a field name and bit range."
                )
                return
            register["fields"][field_index] = updated
        else:
            return

        self.mark_dirty()
        self.refresh_tree()

    def remove_selected(self):
        if not self.data:
            return

        item = self.tree.currentItem()
        if item is None:
            return

        if item.text(1) == "Register":
            index = self.selected_register_index()
            if index is None:
                return
            description = self.data["registers"][index]["name"]
            del self.data["registers"][index]

        elif item.text(1).startswith("Field"):
            index = self.selected_register_index()
            if index is None:
                return
            register = self.data["registers"][index]
            field_index = item.parent().indexOfChild(item)
            description = register["fields"][field_index]["name"]
            del register["fields"][field_index]
        else:
            return

        self.mark_dirty()
        self.refresh_tree()
        self.log_message(f"Removed: {description}")
    def check_block(self):
        if not self.data:
            self.log_message("CHECK FAILED: No register block loaded.", color="red")
            return

        if not self.current_file:
            self.log_message("CHECK FAILED: No HJSON file is associated with this block.", color="red")
            return

        # Save the current GUI contents before checking the file.
        if not self.save_hjson():
            self.log_message("CHECK FAILED: Could not save the current HJSON.", color="red")
            return

        hjson_file = self.current_file.resolve()

        # Resolve paths relative to registrator.py, regardless of the launch directory.
        repo_root = Path(__file__).resolve().parents[3]
        regtool = repo_root / "rtl" / "cobalt_periph" / "tools" / "util" / "reggen" / "regtool.py"

        # Invalidate any previous successful check.
        for action in self.export_actions:
            action.setEnabled(False)

        if not regtool.is_file():
            self.log_message(f"CHECK FAILED: regtool.py not found: {regtool}", color="red")
            return

        command = [
            sys.executable,
            str(regtool),
            "-v",
            str(hjson_file),
        ]

        self.log_message("")
        self.log_message("========== CHECK STARTED ==========")
        self.log_message(f"File: {hjson_file}")
        self.log_message(f"Command: {' '.join(command)}")

        try:
            result = subprocess.run(
                command,
                cwd=repo_root,
                capture_output=True,
                text=True,
                timeout=60,
                check=False,
            )

            # regtool's verbose output, including the printed HJSON.
            if result.stdout.strip():
                self.log_message(result.stdout.rstrip())

            if result.stderr.strip():
                self.log_message(result.stderr.rstrip())

            if result.returncode != 0:
            #    self.log_message(
            #        f"CHECK FAILED: regtool.py exited with code "
            #        f"{result.returncode}."
            #    )
                self.log_message(
                    f"CHECK FAILED: regtool.py exited with code "
                    f"{result.returncode}.",
                    color="red"
                )
                return

            self.log_message(
                "CHECK PASSED: HJSON validation succeeded.",
                color="green"
            )
            for action in self.export_actions:
                action.setEnabled(True)

            self.statusBar().showMessage("Check passed — export enabled")

        except subprocess.TimeoutExpired:
            self.log_message(
                f"CHECK FAILED: regtool.py timed out after 60 seconds.",
                color="red"
            )

        except OSError as error:
            self.log_message(f"CHECK FAILED: Could not execute regtool.py: {error}", color="red")


        self.log_message(
            f"CHECK: Requested validation for '{self.data.get('name', 'Unnamed')}'."
        )

    def export_block(self, export_type):
        if not self.data:
            self.log_message(
                f"EXPORT {export_type} FAILED: No register block loaded.",
                color="red",
            )
            return

        if export_type == "DOC":
            self.export_doc()
            return

        if export_type != "RTL":
            self.log_message(f"EXPORT {export_type}: Command execution not implemented yet.")
            return

        if not self.current_file or not self.current_file.is_file():
            self.log_message(
                "EXPORT RTL FAILED: No saved HJSON file is associated with this block.",
                color="red",
            )
            return

        if self.dirty:
            self.log_message(
                "EXPORT RTL FAILED: Save and check the HJSON before exporting.",
                color="red",
            )
            return

        output_directory = QFileDialog.getExistingDirectory(
            self,
            "Select RTL output directory",
            str(self.current_file.parent),
        )
        if not output_directory:
            return

        repo_root = Path(__file__).resolve().parents[3]
        regtool = (
            repo_root / "rtl" / "cobalt_periph" / "tools" / "util"
            / "reggen" / "regtool.py"
        )
        if not regtool.is_file():
            self.log_message(
                f"EXPORT RTL FAILED: regtool.py not found: {regtool}",
                color="red",
            )
            return

        output_path = Path(output_directory).resolve()
        command = [
            sys.executable,
            str(regtool),
            "-r",
            "-t",
            str(output_path),
            str(self.current_file.resolve()),
        ]

        self.log_message("========== RTL EXPORT STARTED ==========")
        self.log_message(f"HJSON: {self.current_file.resolve()}")
        self.log_message(f"Output directory: {output_path}")
        self.log_message(f"Command: {' '.join(command)}")

        try:
            result = subprocess.run(
                command,
                cwd=repo_root,
                capture_output=True,
                text=True,
                timeout=60,
                check=False,
            )

            if result.stdout.strip():
                self.log_message(result.stdout.rstrip())
            if result.stderr.strip():
                self.log_message(result.stderr.rstrip())

            if result.returncode != 0:
                self.log_message(
                    f"EXPORT RTL FAILED: regtool.py exited with code {result.returncode}.",
                    color="red",
                )
                return

            self.log_message(
                f"EXPORT SUCCESSFUL: RTL saved to {html.escape(str(output_path))}",
                color="green",
            )
            self.statusBar().showMessage(f"RTL export successful: {output_path}")

        except subprocess.TimeoutExpired:
            self.log_message(
                "EXPORT RTL FAILED: regtool.py timed out after 60 seconds.",
                color="red",
            )
        except OSError as error:
            self.log_message(
                f"EXPORT RTL FAILED: Could not execute regtool.py: {error}",
                color="red",
            )

    def export_doc(self):
        if not self.current_file or not self.current_file.is_file():
            self.log_message(
                "EXPORT DOC FAILED: No saved HJSON file is associated with this block.",
                color="red",
            )
            return

        if self.dirty:
            self.log_message(
                "EXPORT DOC FAILED: Save and check the HJSON before exporting.",
                color="red",
            )
            return

        default_name = text_value(
            self.data.get("name"), self.current_file.stem
        ).strip() or self.current_file.stem
        suggested_path = self.current_file.parent / f"{default_name}.html"
        output_filename, selected_filter = QFileDialog.getSaveFileName(
            self,
            "Save register documentation",
            str(suggested_path),
            "HTML files (*.html);;Markdown files (*.md)",
        )
        if not output_filename:
            return
        is_markdown = selected_filter.startswith("Markdown")
        extension = ".md" if is_markdown else ".html"

        repo_root = Path(__file__).resolve().parents[3]
        regtool = (
            repo_root / "rtl" / "cobalt_periph" / "tools" / "util"
            / "reggen" / "regtool.py"
        )
        if not regtool.is_file():
            self.log_message(
                f"EXPORT DOC FAILED: regtool.py not found: {regtool}",
                color="red",
            )
            return

        output_path = Path(output_filename).expanduser().resolve()
        output_path = output_path.with_suffix(extension)
        command = [
            sys.executable,
            str(regtool),
            "-d",
            str(self.current_file.resolve()),
        ]

        self.log_message("========== DOC EXPORT STARTED ==========")
        self.log_message(f"HJSON: {self.current_file.resolve()}")
        self.log_message(f"Output file: {output_path}")
        self.log_message(f"Command: {' '.join(command)}")

        try:
            result = subprocess.run(
                command,
                cwd=repo_root,
                capture_output=True,
                text=True,
                encoding="utf-8",
                timeout=60,
                check=False,
            )

            if result.stderr.strip():
                self.log_message(result.stderr.rstrip())

            if result.returncode != 0:
                self.log_message(
                    f"EXPORT DOC FAILED: regtool.py exited with code {result.returncode}.",
                    color="red",
                )
                return

            if is_markdown:
                document = QTextDocument()
                document.setHtml(result.stdout)
                output_content = document.toMarkdown()
            else:
                output_content = result.stdout

            if not output_content.strip():
                self.log_message(
                    "EXPORT DOC FAILED: regtool.py produced empty documentation.",
                    color="red",
                )
                return

            output_path.write_text(output_content, encoding="utf-8")
            self.log_message(
                f"EXPORT SUCCESSFUL: DOC saved to {html.escape(str(output_path))}",
                color="green",
            )
            self.statusBar().showMessage(f"DOC export successful: {output_path}")

        except subprocess.TimeoutExpired:
            self.log_message(
                "EXPORT DOC FAILED: regtool.py timed out after 60 seconds.",
                color="red",
            )
        except OSError as error:
            self.log_message(
                f"EXPORT DOC FAILED: Could not generate/write documentation: {error}",
                color="red",
            )

    def save_hjson(self):
        if not self.data:
            return False

        if not self.current_file:
            filename, _ = QFileDialog.getSaveFileName(
                self, "Save HJSON", str(Path.home() / "SYSCTRL.hjson"),
                "HJSON files (*.hjson);;All files (*)"
            )
            if not filename:
                return False
            self.current_file = Path(filename)

        self.metadata_changed()

        try:
            self.current_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self.current_file, "w", encoding="utf-8") as stream:
                # JSON is valid HJSON, and preserves string-valued fields.
                json.dump(self.data, stream, indent=2, ensure_ascii=False)
                stream.write("\n")

            self.dirty = False
            self.project_label.setText(str(self.current_file))
            self.statusBar().showMessage(f"Saved: {self.current_file}")
            self.log_message(f"Saved: {self.current_file}")
            return True
        except Exception as error:
            QMessageBox.critical(self, "Save failed", str(error))
            return False

    def closeEvent(self, event):
        if self.confirm_discard():
            event.accept()
        else:
            event.ignore()


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Cobalt RegGen")
    window = RegGenWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()