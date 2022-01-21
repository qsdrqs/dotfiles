#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''
Created on 12/30/2020

@author qsdrqs
'''

# Import the class
import ranger.gui.context
import ranger.gui.widgets.browsercolumn

my_keys = ['msdoc', 'pdf', 'msppt', 'msxls', 'apk']

# Set them to False
for key in my_keys:
    ranger.gui.context.CONTEXT_KEYS.append(key)
    code = 'ranger.gui.context.Context.' + key + ' = False'
    exec(code)

OLD_HOOK_BEFORE_DRAWING = ranger.gui.widgets.browsercolumn.hook_before_drawing


def new_hook_before_drawing(fsobject, color_list):
    full_name: str = fsobject.basename
    # has suffix
    if full_name.find('.') != -1:
        # msdoc
        if full_name.split('.')[-1] in ['docx', 'doc']:
            color_list.append('msdoc')
        # pdf
        if full_name.split('.')[-1] in ['pdf']:
            color_list.append('pdf')
        # ppt
        if full_name.split('.')[-1] in ['ppt', 'pptx']:
            color_list.append('msppt')
        # xls
        if full_name.split('.')[-1] in ['xls','xlsx']:
            color_list.append('msxls')
        # apk
        if full_name.split('.')[-1] in ['apk']:
            color_list.append('apk')



    return OLD_HOOK_BEFORE_DRAWING(fsobject, color_list)


ranger.gui.widgets.browsercolumn.hook_before_drawing = new_hook_before_drawing
