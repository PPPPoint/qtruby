/**********************************************************************
** Copyright (C) 2000 Trolltech AS.  All rights reserved.
**
** This file is part of Qt Designer.
**
** This file may be distributed and/or modified under the terms of the
** GNU General Public License version 2 as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL included in the
** packaging of this file.
**
** This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
** WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
**
** See http://www.trolltech.com/gpl/ for GPL licensing information.
**
** Contact info@trolltech.com if any conditions of this licensing are
** not clear to you.
**
**********************************************************************/

#include "uic.h"
#include "parser.h"
#include "widgetdatabase.h"
#include "domtool.h"
#include <qfile.h>
#include <qstringlist.h>
#include <qdatetime.h>
#define NO_STATIC_COLORS
#include <globaldefs.h>
#include <qregexp.h>
#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>


/*!
  Creates an implementation for a subclass \a subClass of the form
  given in \a e

  \sa createSubDecl()
 */
void Uic::createSubImpl( const QDomElement &e, const QString& subClass )
{
    QDomElement n;
    QDomNodeList nl;
    int i;
    QStringList::Iterator it, it2, it3;

    QString objClass = getClassName( e );
    if ( objClass.isEmpty() )
	return;
	if (hasKDEwidget) {
    	out << indent << "require 'Korundum'" << endl;
	} else {
    	out << indent << "require 'Qt'" << endl;
	}
    out << endl;
    out << indent << "class " << subClass << " < " << nameOfClass << endl;

    out << endl;
    ++indent;

    // constructor
    if ( objClass == "Qt::Dialog" || objClass == "Qt::Wizard" ) {
	out << indent << "#  Constructs a " << subClass << " which is a child of 'parent', with the " << endl;
	out << indent << "#  name 'name' and widget flags set to 'fl' " << endl;
	out << indent << "#  " << endl;
	out << indent << "#  The " << objClass.mid(4).lower() << " will by default be modeless, unless you set 'modal' to" << endl;
	out << indent << "#  true to construct a modal " << objClass.mid(4).lower() << "." << endl;
    out << indent << "def initialize(parent = nil, name = nil, modal = false, fl = 0)" << endl;
    ++indent;
	out << indent << "super" << endl;
    } else {
	out << indent << "#  Constructs a " << subClass << " which is a child of 'parent', with the " << endl;
	out << indent << "#  name 'name' and widget flags set to 'fl' " << endl;
    out << indent << "def initialize(parent = nil, name = nil, fl = 0)" << endl;
    ++indent;
	out << indent << "super" << endl;
    }
    --indent;
    out << indent << "end" << endl;
    out << endl;

    // find additional slots
    QStringList publicSlots, protectedSlots, privateSlots;
    QStringList publicSlotTypes, protectedSlotTypes, privateSlotTypes;
    QStringList publicSlotSpecifier, protectedSlotSpecifier, privateSlotSpecifier;
    QMap<QString, QString> functionImpls;
    nl = e.parentNode().toElement().elementsByTagName( "slot" );
    for ( i = 0; i < (int) nl.length(); i++ ) {
	n = nl.item(i).toElement();
	if ( n.parentNode().toElement().tagName() != "slots"
	     && n.parentNode().toElement().tagName() != "connections" )
	    continue;
	if ( n.attribute( "language", "C++" ) != "C++" )
	    continue;
	QString returnType = n.attribute( "returnType", "void" );
	QString slotName = n.firstChild().toText().data().stripWhiteSpace();
	if ( slotName.endsWith( ";" ) )
	    slotName = slotName.left( slotName.length() - 1 );
	QString specifier = n.attribute( "specifier" );
	QString access = n.attribute( "access" );
	if ( access == "protected" ) {
	    protectedSlots += slotName;
	    protectedSlotTypes += returnType;
	    protectedSlotSpecifier += specifier;
	} else if ( access == "private" ) {
	    privateSlots += slotName;
	    privateSlotTypes += returnType;
	    privateSlotSpecifier += specifier;
	} else {
	    publicSlots += slotName;
	    publicSlotTypes += returnType;
	    publicSlotSpecifier += specifier;
	}
    }


    // compatibility with early 3.0 betas
    nl = e.parentNode().toElement().elementsByTagName( "function" );
    for ( i = 0; i < (int) nl.length(); i++ ) {
	QString fname = n.attribute( "name" );
	fname = Parser::cleanArgs( fname );
	functionImpls.insert( fname, n.firstChild().toText().data() );
    }
    // create stubs for public additional slots
    if ( !publicSlots.isEmpty() ) {
	for ( it = publicSlots.begin(), it2 = publicSlotTypes.begin(), it3 = publicSlotSpecifier.begin();
	      it != publicSlots.end(); ++it, ++it2, ++it3 ) {
	    QString pure;
	    QString type = *it2;
	    if ( type.isEmpty() )
		type = "void";
	    if ( *it3 == "non virtual" )
		continue;
	    if ( isEmptyFunction( *it ) ) {
	        out << endl;
	        int astart = (*it).find('(');
	        out << indent << "def " << (*it).left(astart)<< "(*k)" << endl;
		++indent;
		out << indent << "print(\"" << subClass << "." << (*it) << ": Not implemented yet.\\n\")" << endl;
		--indent;
                out << indent << "end" << endl;
	    }
	}
    }

    // create stubs for protected additional slots
    if ( !protectedSlots.isEmpty() ) {
	for ( it = protectedSlots.begin(), it2 = protectedSlotTypes.begin(), it3 = protectedSlotSpecifier.begin();
	      it != protectedSlots.end(); ++it, ++it2, ++it3 ) {
	    QString pure;
	    QString type = *it2;
	    if ( type.isEmpty() )
		type = "void";
	    if ( *it3 == "non virtual" )
		continue;
	    if ( isEmptyFunction( *it ) ) {
	        out << endl;
	        int astart = (*it).find('(');
	        out << indent << "def " << (*it).left(astart)<< "(*k)" << endl;
		++indent;
		out << indent << "print(\"" << subClass << "." << (*it) << ": (Protected) Not implemented yet.\\n\")" << endl;
		--indent;
                out << indent << "end" << endl;
	        out << indent << "protected :" << (*it).left(astart)<< endl;
	    }
	}
    }


    // create stubs for private additional slots
    if ( !privateSlots.isEmpty() ) {
	for ( it = privateSlots.begin(), it2 = privateSlotTypes.begin(), it3 = privateSlotSpecifier.begin();
	      it != privateSlots.end(); ++it, ++it2, ++it3 ) {
	    QString pure;
	    QString type = *it2;
	    if ( type.isEmpty() )
		type = "void";
	    if ( *it3 == "non virtual" )
		continue;
	    if ( isEmptyFunction( *it ) ) {
	        out << endl;
	        int astart = (*it).find('(');
	        out << indent << "def " << (*it).left(astart)<< "(*k)" << endl;
		++indent;
		out << indent << "print(\"" << subClass << "." << (*it) << ": (Private) Not implemented yet.\\n\")" << endl;
		--indent;
                out << indent << "end" << endl;
	        out << indent << "private :" << (*it).left(astart)<< endl;
	    }
	}
    }

	--indent;
    out << indent << "end" << endl;
}