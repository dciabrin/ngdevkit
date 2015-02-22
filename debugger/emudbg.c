/*
 * emudbg - emulator-agnostic source level debugging API
 * Copyright (c) 2015 Damien Ciabrini
 * This file is part of ngdevkit
 *
 * ngdevkit is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * ngdevkit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with ngdevkit.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <sys/ioctl.h>
#include <Python.h>

#include "emudbg.h"


#define FD_NONE -1

static struct emudbg_api_t *debugger_impl;
int listen_socket=FD_NONE;
int client_socket=FD_NONE;

PyObject *pInitServerFunc;
PyObject *pWaitForClientFunc;
PyObject *pServerLoopFunc;


int emudbg_init(struct emudbg_api_t *impl) {
    PyObject *pName, *pModule;
    int i;

    debugger_impl = impl;

    Py_Initialize();
    pName = PyString_FromString("emudbgserver");

    pModule = PyImport_Import(pName);
    Py_DECREF(pName);
    if (pModule == NULL) {
        PyErr_Print();
        return 1;
    }

    pInitServerFunc = PyObject_GetAttrString(pModule, "init_server");
    if (!(pInitServerFunc && PyCallable_Check(pInitServerFunc))) {
        Py_DECREF(pInitServerFunc);
        Py_DECREF(pModule);
        PyErr_Print();
        return 1;
    }

    pWaitForClientFunc = PyObject_GetAttrString(pModule, "wait_for_client");
    if (!(pWaitForClientFunc && PyCallable_Check(pWaitForClientFunc))) {
        Py_DECREF(pWaitForClientFunc);
        Py_DECREF(pInitServerFunc);
        Py_DECREF(pModule);
        PyErr_Print();
        return 1;
    }

    pServerLoopFunc = PyObject_GetAttrString(pModule, "server_loop");
    if (!(pServerLoopFunc && PyCallable_Check(pServerLoopFunc))) {
        Py_DECREF(pServerLoopFunc);
        Py_DECREF(pWaitForClientFunc);
        Py_DECREF(pInitServerFunc);
        Py_DECREF(pModule);
        PyErr_Print();
        return 1;
    }

    PyObject *pValue;

    pValue = PyObject_CallFunction(pInitServerFunc, "k", (long)debugger_impl);
    if (pValue!=NULL) {
        listen_socket=(int)PyInt_AsLong(pValue);
        Py_DECREF(pValue);
        return 0;
    } else {
        PyErr_Print();
        return 1;
    }

    return 0;
}

int emudbg_wait_for_client(void) {
    PyObject *pValue;

    pValue = PyObject_CallFunction(pWaitForClientFunc, "", NULL);
    if (pValue!=NULL) {
        client_socket=(int)PyInt_AsLong(pValue);
        Py_DECREF(pValue);
        return 0;
    } else {
        PyErr_Print();
        return 1;
    }
}

int emudbg_client_command_pending(void) {
    int bytes_avail=0;
    if (client_socket != FD_NONE) {
        ioctl(client_socket, FIONREAD, &bytes_avail);
    }
    return bytes_avail>0;
}


int emudbg_server_loop(int emu_suspended, struct emudbg_cmd_t *next_cmd) {
    PyObject *pValue;
    pValue = PyObject_CallFunction(pServerLoopFunc, "il",
                                   emu_suspended, (long)next_cmd);
    if (pValue!=NULL) {
        Py_DECREF(pValue);
        return 0;
    } else {
        PyErr_Print();
        return 1;
    }
}

void emudbg_disconnect_from_client(void) {
    listen_socket = FD_NONE;
}
