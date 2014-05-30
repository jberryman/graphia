#ifndef ABSTRACTSCENE_H
#define ABSTRACTSCENE_H

#include <QObject>

class QOpenGLContext;
class QMouseEvent;
class QWheelEvent;
class QKeyEvent;

class AbstractScene : public QObject
{
    Q_OBJECT

public:
    AbstractScene( QObject* parent = 0 );
    virtual ~AbstractScene();

    void setContext(QOpenGLContext* context) { _context = context; }
    QOpenGLContext* context() const { return _context; }

    virtual void initialise() = 0;
    virtual void cleanup() {}
    virtual void update(float t) = 0;
    virtual void render() = 0;
    virtual void resize(int w, int h) = 0;

    virtual void mousePressEvent(QMouseEvent*) {}
    virtual void mouseReleaseEvent(QMouseEvent*) {}
    virtual void mouseMoveEvent(QMouseEvent*) {}
    virtual void mouseDoubleClickEvent(QMouseEvent*) {}
    virtual void wheelEvent(QWheelEvent*) {}

    virtual bool keyPressEvent(QKeyEvent*) { return false; }
    virtual bool keyReleaseEvent(QKeyEvent*) { return false; }

protected:
    QOpenGLContext* _context;
};

#endif // ABSTRACTSCENE_H
