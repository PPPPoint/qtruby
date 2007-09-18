/***************************************************************************
 *   Copyright (C) 2005,2006,2007 by Siraj Razick <siraj@kdemail.net>      *
 *   Copyright (C) 2007 by Riccardo Iaconelli <ruphy@fsfe.org>             *
 *   Copyright (C) 2007 by Matthias Kretz <kretz@kde.org>                  *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/

#include <ruby.h>

#include <QString>
#include <QFileInfo>

#include <KStandardDirs>
#include <klibloader.h>

/*
    Duplication the definition of this struct, to avoid linking directly
    against the QtRuby libs
*/
struct smokeruby_object {
    bool allocated;
    void *smoke;
    int classId;
    void *ptr;
};

class KRubyPluginFactory : public KPluginFactory
{
    public:
        KRubyPluginFactory();

    protected:
        virtual QObject *create(const char *iface, QWidget *parentWidget, QObject *parent, const QVariantList &args, const QString &keyword);
};
K_EXPORT_PLUGIN(KRubyPluginFactory)

KRubyPluginFactory::KRubyPluginFactory()
    : KPluginFactory() // no useful KComponentData object for now
{
}

QObject *KRubyPluginFactory::create(const char *iface, QWidget *parentWidget, QObject *parent, const QVariantList &args, const QString &keyword)
{
    Q_UNUSED(iface);
    Q_UNUSED(parentWidget);
    Q_UNUSED(parent);
    Q_UNUSED(args);

    // suggestion for script lookup:
    //KStandardDirs::locate("data", QString::fromLatin1(iface) + QLatin1Char('/') + keyword);
    QString path = KStandardDirs::locate("data", keyword);

    if (path.isEmpty()) {
        kWarning() << "Ruby script" << keyword << "missing";
        return 0;
    }

    QFileInfo program(path);

    ruby_init();
    ruby_script(QFile::encodeName(program.fileName()));
    ruby_init_loadpath();

    ruby_incpush(QFile::encodeName(program.path()));

    int state = 0;
    const QByteArray encodedFilePath = QFile::encodeName(program.filePath());
    rb_load_protect(rb_str_new2(encodedFilePath), 0, &state);
    if (state != 0) {
        kWarning() << "Failed to load" << encodedFilePath;
        return 0;
    }

    QByteArray className = program.baseName().toLatin1();
    className = className.left(1).toUpper() + className.right(className.length() - 1);
    VALUE plugin_class = rb_const_get(rb_cObject, rb_intern(className));
    if (plugin_class == Qnil) {
        kWarning() << "no" << className << "class found";
        return 0;
    }

    VALUE av = rb_ary_new();
    for (int i = 0; i < args.size(); ++i) {
        if (args.at(i).type() == QVariant::String) {
            rb_ary_push(av, rb_str_new2(args.at(i).toByteArray()));
        } else if (args.at(i).type() == QVariant::Int) {
            rb_ary_push(av, INT2NUM(args.at(i).toInt()));
        } else if (args.at(i).type() == QVariant::Bool) {
            rb_ary_push(av, args.at(i).toBool() ? Qtrue : Qfalse);
        }
    }

    VALUE plugin_value = rb_funcall(plugin_class, rb_intern("new"), 2, Qnil, av);
    if (plugin_value == Qnil) {
        kWarning() << "failed to create instance of plugin class";
        return 0;
    }

    smokeruby_object *o = 0;
    Data_Get_Struct(plugin_value, smokeruby_object, o);
    QObject * createdInstance = reinterpret_cast<QObject *>(o->ptr);
    createdInstance->setParent(parent);
    return createdInstance;
}
