/*
 * Copyright 2003-2011 Ian Monroe <imonroe@kde.org>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) version 3, or any
 * later version accepted by the membership of KDE e.V. (or its
 * successor approved by the membership of KDE e.V.), which shall
 * act as a proxy defined in Section 6 of version 3 of the license.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public 
 * License along with this library.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <QtCore/QByteArray>
#include <QtCore/QVariant>
#include <QtCore/QtDebug>
#include <QtCore/QDateTime>
#include <QtCore/QRegExp>
#include <QtCore/QStringList>

#include "smoke/qtcore_smoke.h"

#include "debug.h"
#include "utils.h"
#include "marshall.h"
#include "methodcall.h"
#include "global.h"

namespace QtRuby {

QByteArray 
constructorName(const Smoke::ModuleIndex& classId)
{
    QByteArray name(classId.smoke->classes[classId.index].className);
    int pos = name.lastIndexOf("::");
    
    if (pos != -1) {
        name = name.mid(pos + strlen("::"));
    }
    
    return name;
}

static QByteArray
typeName(const Smoke::Type& typeRef)
{
    QByteArray name(typeRef.name);
    return name.replace("const ", "").replace("&", "").replace("*", "");
}

/* http://lists.kde.org/?l=kde-bindings&m=105167029023219&w=2
* The handler will first determine the Qt class hierarchy of the object (using 
* Smoke's idClass() and looking in the class hierarchy array) then build the 
* munged prototype of the requested method, following those rules:
* - take the requested method name
* - append $ for each simple native type argument (string, numeral, etc...) 
* - append  # for each Qt object passed as argument
* - append ? for things like an array, or a hash, or an undefined value     
*/
static QVector<QByteArray> 
mungedMethods(const QByteArray& methodName, int argc, VALUE * args, MethodMatchesState matchState)
{
    QVector<QByteArray> result;
    result.append(methodName);

    for (int i = 0; i < argc; ++i) {
        VALUE value = args[i];
        if (    TYPE(value) == T_FIXNUM
                || TYPE(value) == T_BIGNUM
                || value == Qtrue
                || value == Qfalse
//                || value.instanceOf(QtRuby::Global::QtEnum) )
                || TYPE(value) == T_STRING )
        {
            if (matchState == ImplicitTypeConversionsState) {
                QVector<QByteArray> temp;
                foreach (QByteArray mungedMethod, result) {
                    temp.append(mungedMethod + '$');
                    temp.append(mungedMethod + '#');
                }
                result = temp;
            } else {
                for (int i = 0; i < result.count(); i++) {
                    result[i] += '$';
                }
            }
        } else if (TYPE(value) == T_ARRAY) {
            if (matchState == ImplicitTypeConversionsState) {
                QVector<QByteArray> temp;
                foreach (QByteArray mungedMethod, result) {
                    temp.append(mungedMethod + '?');
                    temp.append(mungedMethod + '#');
                }
                result = temp;
            } else {
                for (int i = 0; i < result.count(); i++) {
                    result[i] += '?';
                }
            }
        } else if (value == Qnil) {
            QVector<QByteArray> temp;
            foreach (QByteArray mungedMethod, result) {
                temp.append(mungedMethod + '$');
                temp.append(mungedMethod + '?');
                temp.append(mungedMethod + '#');
            }
            result = temp;
        } else if (TYPE(value) == T_DATA)
//                    || value.isDate()
//                    || value.isRegExp() )
        {
            for (int i = 0; i < result.count(); i++) {
                result[i] += '#';
            }
        } else {
            VALUE str = rb_funcall(value, rb_intern("to_s"), 0, 0);
            qDebug() << Q_FUNC_INFO << "Unknown value type:" << str;
        }
    }

    return result;
}

static int
inheritanceDistance(Smoke* smoke, Smoke::Index classId, Smoke::Index baseId, int distance)
{
    if (baseId == 0) {
        return 100;
    }
    
    if (classId == baseId) {
        return distance;
    }
    
    for (   Smoke::Index* parent = smoke->inheritanceList + smoke->classes[classId].parents; 
            *parent != 0; 
            parent++ ) 
    {
        int result = inheritanceDistance(smoke, *parent, baseId, distance + 1);
        if (result != 100) {
            return result;
        }
    }
    
    return 100;
}

// The code to match method arguments here, is based on callQtMethod() 
// in script/qscriptextqobject.cpp
//
static int 
matchArgument(VALUE actual, const Smoke::Type& typeRef)
{
    QByteArray fullArgType(typeRef.name);
    fullArgType.replace("const ", "");
    QByteArray argType(typeName(typeRef));    
    int matchDistance = 0;
    
    if (TYPE(actual) == T_FIXNUM || TYPE(actual) == T_BIGNUM) {
        switch (typeRef.flags & Smoke::tf_elem) {
        case Smoke::t_enum:
            matchDistance += 1;
            break;
        case Smoke::t_double:
            // perfect
            break;
        case Smoke::t_float:
            matchDistance += 1;
            break;
        case Smoke::t_long:
        case Smoke::t_ulong:
            matchDistance += 3;
            break;
        case Smoke::t_int:
        case Smoke::t_uint:
            matchDistance += 4;
            break;
        case Smoke::t_short:
        case Smoke::t_ushort:
            matchDistance += 5;
            break;
        case Smoke::t_char:
        case Smoke::t_uchar:
            matchDistance += 6;
            break;
        default:
        {
            if (QString::fromLatin1(fullArgType).contains(QRegExp("^(signed|unsigned)?(bool|char|short|int|long|double)[&*]$")))
                matchDistance += 7;
            else
                matchDistance += 100;
            break;
        }
        }
//    } else if (actual.instanceOf(QtRuby::Global::QtEnum)) {
    } else if (false) {
        switch (typeRef.flags & Smoke::tf_elem) {
        case Smoke::t_enum:
//            if (actual.property("typeName").toString().toLatin1() != argType) {
//                matchDistance += 100;
//            }
            break;
        case Smoke::t_uint:
            matchDistance += 1;
            break;                    
        case Smoke::t_int:
            matchDistance += 2;
            break;                    
        case Smoke::t_long:
        case Smoke::t_ulong:
            matchDistance += 3;
            break;
        default:
            matchDistance += 100;
            break;
        }
    } else if (TYPE(actual) == T_STRING) {
        if (argType == "QString") {
        } else if (fullArgType == "char*" || fullArgType == "unsigned char*") {
            matchDistance += 1;
        } else if (argType == "QChar") {
            matchDistance += 2;
        } else {
            matchDistance += 100;
        }
    } else if (actual == Qtrue || actual == Qfalse) {
        if ((typeRef.flags & Smoke::tf_elem) == Smoke::t_bool) {
        } else {
            matchDistance += 100;
        }
//    } else if (actual.isDate()) {
//        if (argType == "QDataTime") {
//        } else if (argType == "QDate") {
//            matchDistance += 1;
//        } else if (argType == "QTime") {
//            matchDistance += 2;
//        } else {
//            matchDistance += 100;
//        }
//    } else if (actual.isRegExp()) {
//        if (argType == "QRegExp") {
//        } else {
//            matchDistance += 100;
//        }
    } else if (TYPE(actual) == T_DATA) {
        if ((typeRef.flags & Smoke::t_class) != 0) {
            Object::Instance * instance = Object::Instance::get(actual);
            Smoke::ModuleIndex classId = instance->classId.smoke->idClass(argType, true);
            matchDistance += inheritanceDistance(instance->classId.smoke, instance->classId.index, classId.index, 0);
        } else {
            matchDistance += 100;
        }
//    } else if (actual.isVariant()) {
    } else if (TYPE(actual) == T_ARRAY) {
        if (    argType.contains("QVector") 
                || argType.contains("QList")
                || argType.contains("QStringList")
                || fullArgType.contains("char**")
                || QString::fromLatin1(fullArgType).contains(QRegExp("^(signed|unsigned)?(bool|char|short|int|long|double)[&*]$")) )
        {
        } else {
            matchDistance += 100;
        }
//    } else if (actual.isQObject()) {
    } else if (actual == Qnil) {
//    } else if (actual.isObject()) {
    } else {
        matchDistance += 100;
    }
    
    return matchDistance;
}

static QVector<Smoke::ModuleIndex>
findCandidates(Smoke::ModuleIndex classId, const QVector<QByteArray>& mungedMethods)
{
    Smoke::Class & klass = classId.smoke->classes[classId.index];
    QVector<Smoke::ModuleIndex> methodIds;

    foreach (QByteArray mungedMethod, mungedMethods) {
        Smoke::ModuleIndex methodId = classId.smoke->findMethod(klass.className, mungedMethod);

        if (methodId.index == 0) {
            // Look in the global namespaces of all the open smoke modules
            QHashIterator<Smoke*, Module> it(Global::modules);
            while (it.hasNext()) {
                it.next();
                Smoke * smoke = it.key();
                methodId = smoke->findMethod(   smoke->idClass("QGlobalSpace"), 
                                                smoke->idMethodName(mungedMethod) );
                
                if (methodId != Smoke::NullModuleIndex) {
                    methodIds.append(methodId);
                }
            }
        } else {
            methodIds.append(methodId);
        }
    }
    
    QVector<Smoke::ModuleIndex> candidates;
    
    foreach (Smoke::ModuleIndex methodId, methodIds) {
        Smoke::Index ix = methodId.smoke->methodMaps[methodId.index].method;
        Smoke::ModuleIndex mi;
        if (ix == 0) {
        } else if (ix > 0) {
            mi.index = ix;
            mi.smoke = methodId.smoke;
            candidates.append(mi);
        } else if (ix < 0) {
            ix = -ix;
            while (methodId.smoke->ambiguousMethodList[ix] != 0) {
                mi.index = methodId.smoke->ambiguousMethodList[ix];
                mi.smoke = methodId.smoke;
                candidates.append(mi);
                ix++;
            }
        }        
    }
    
    return candidates;
}

MethodMatches 
resolveMethod(  Smoke::ModuleIndex classId, 
                const QByteArray& methodName, 
                int argc,
                VALUE * args,
                MethodMatchesState matchState )
{
    QVector<QByteArray> mungedMethods = QtRuby::mungedMethods(methodName, argc, args, matchState);
    QVector<Smoke::ModuleIndex> candidates = findCandidates(classId, mungedMethods);
    MethodMatches matches;
        
    foreach (Smoke::ModuleIndex method, candidates) {
        Smoke::Method& methodRef = method.smoke->methods[method.index];
        
        if ((methodRef.flags & Smoke::mf_internal) == 0) {
            QVector<Smoke::ModuleIndex> methods;
            methods.append(method);
            int matchDistance = 0;
            
            // If a method is overloaded only on const-ness, prefer the
            // non-const version
            if ((methodRef.flags & Smoke::mf_const) != 0) {
                matchDistance += 1;
            }
            
            for (int i = 0; i < methodRef.numArgs; i++) {
                VALUE actual = args[i];
                ushort argFlags = method.smoke->types[method.smoke->argumentList[methodRef.args+i]].flags;
                int distance = matchArgument(actual, method.smoke->types[method.smoke->argumentList[methodRef.args+i]]);
                
                if (matchState == ImplicitTypeConversionsState) {
                    if ((argFlags & Smoke::tf_elem) == Smoke::t_class && distance >= 100) {
                        QByteArray className = typeName(method.smoke->types[method.smoke->argumentList[methodRef.args+i]]);
                        Smoke::ModuleIndex argClassId = Smoke::findClass(className);
                        MethodMatches cmatches = resolveMethod( argClassId, 
                                                                constructorName(argClassId), 
                                                                1, &actual,
                                                                ArgumentTypeConversionState );
                        
                        if (cmatches.count() > 0 && cmatches[0].second <= 10) {
                            matchDistance += cmatches[0].second;
                            methods.append(cmatches[0].first[0]);
                            continue;
                        }
                        
                        if (TYPE(actual) == T_DATA) {
                            Object::Instance * instance = Object::Instance::get(actual);
                            cmatches = resolveMethod(   instance->classId, 
                                                        QByteArray("operator ") + className, 
                                                        0, 0,
                                                        ArgumentTypeConversionState );
                            
                            if (cmatches.count() > 0 && cmatches[0].second <= 10) {
                                matchDistance += cmatches[0].second;
                                methods.append(cmatches[0].first[0]);
                                continue;
                            }
                        }
                    }
                    
                    methods.append(Smoke::NullModuleIndex);
                }
                
                matchDistance += distance;
            }
            
            if (matches.count() > 0 && matchDistance <= matches[0].second) {
                matches.prepend(MethodMatch(methods, matchDistance));
            } else {
                matches.append(MethodMatch(methods, matchDistance));
            }
        }
    }

    if (    matchState == InitialState
            && (matches.count() == 0 || matches[0].second >= 100) )
    {
        // Failed to find a matching method, so try again assuming implicit type 
        // conversions can be done for the arguments
        matches = resolveMethod(classId, methodName, argc, args, ImplicitTypeConversionsState);
    }
    
    if (matchState != ImplicitTypeConversionsState && (Debug::DoDebug & Debug::MethodMatches) != 0) {
        QStringList argsString;
        for (int i = 0; i < argc; ++i) {
            VALUE str = rb_funcall(args[i], rb_intern("to_s"), 0, 0);
            argsString << QString::fromLatin1(StringValuePtr(str));
        }

        qWarning(   "%s@%s:%d for %s.%s(%s):",
                    matchState == InitialState ? "Method matches" : "    Argument type conversion matches",
                    rb_sourcefile(),
                    rb_sourceline(),
                    Global::rubyClassNameFromId(classId).constData(),
                    methodName.constData(),
                    argsString.join(", ").toLatin1().constData() );

        for (int i = 0; i < matches.count(); i++) {
            qWarning("%s%s module: %s index: %d matchDistance: %d", 
                matchState == InitialState ? "    " : "        ",
                Debug::methodToString(matches[i].first[0]).toLatin1().constData(),
                matches[i].first[0].smoke->moduleName(), 
                matches[i].first[0].index, 
                matches[i].second);
        }
    }
    
    return matches;    
}

void *
constructCopy(Object::Instance* instance)
{
    Smoke * smoke = instance->classId.smoke;
    const char *className = smoke->className(instance->classId.index);    
    QByteArray ccSignature = constructorName(instance->classId);
    ccSignature.append("#");    
    QByteArray ccArg("const ");
    ccArg.append(className).append("&");
    Smoke::ModuleIndex ccId = smoke->findMethodName(className, ccSignature);
    Smoke::ModuleIndex ccMethod = smoke->findMethod(instance->classId, ccId);

    if (ccMethod.index == 0) {
        qWarning("QtRuby::constructCopy() failed %s %p\n", className, instance->value);
        return 0;
    }
    
    Smoke::Index method = ccMethod.smoke->methodMaps[ccMethod.index].method;
    if (method > 0) {
        // Make sure it's a copy constructor
        if (ccArg != smoke->types[*(smoke->argumentList + smoke->methods[method].args)].name) {
            qWarning("QtRuby::constructCopy() failed %s %p\n", className, instance->value);
            return 0;
        }

        ccMethod.index = method;
    } else {
        // ambiguous method, pick the copy constructor
        Smoke::Index i = -method;
        while (ccMethod.smoke->ambiguousMethodList[i]) {
            if (ccArg == smoke->types[*(smoke->argumentList + smoke->methods[ccMethod.smoke->ambiguousMethodList[i]].args)].name) {
                break;
            }
            i++;
        }

        ccMethod.index = ccMethod.smoke->ambiguousMethodList[i];
        if (ccMethod.index == 0) {
            qWarning("QtRuby::constructCopy() failed %s %p\n", className, instance->value);
            return 0;
        }
    }

    // Okay, ccMethod is the copy constructor. Time to call it.
    Smoke::StackItem args[2];
    args[0].s_voidp = 0;
    args[1].s_voidp = instance->value;
    Smoke::ClassFn fn = smoke->classes[instance->classId.index].classFn;
    (*fn)(smoke->methods[ccMethod.index].method, 0, args);

    // Initialize the binding for the new instance
    Smoke::StackItem initializeInstanceStack[2];
    initializeInstanceStack[1].s_voidp = Global::modules[instance->classId.smoke].binding;
    (*fn)(0, args[0].s_voidp, initializeInstanceStack);

    return args[0].s_voidp;
}

}
