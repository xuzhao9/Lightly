/*
* Copyright 2014  Martin Gräßlin <mgraesslin@kde.org>
* Copyright 2014  Hugo Pereira Da Costa <hugo.pereira@free.fr>
* Copyright 2018  Vlad Zahorodnii <vlad.zahorodnii@kde.org>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation; either version 2 of
* the License or (at your option) version 3 or any later version
* accepted by the membership of KDE e.V. (or its successor approved
* by the membership of KDE e.V.), which shall act as a proxy
* defined in Section 14 of version 3 of the license.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "lightlydecoration.h"

#include "lightly.h"
#include "lightlysettingsprovider.h"
#include "config-lightly.h"

#include "lightlybutton.h"
#include "lightlysizegrip.h"

#include "lightlyboxshadowrenderer.h"

#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/DecorationButtonGroup>
#include <KDecoration3/DecorationSettings>
#include <KDecoration3/DecorationShadow>
#include <KDecoration3/ScaleHelpers>

#include <KConfigGroup>
#include <KColorUtils>
#include <KSharedConfig>
#include <KPluginFactory>

#include <QPainter>
#include <QTextStream>
#include <QTimer>
#include <QVariantAnimation>

#if LIGHTLY_HAVE_X11
#include <QX11Info>
#endif

#include <cmath>

K_PLUGIN_FACTORY_WITH_JSON(
    LightlyDecoFactory,
    "lightly.json",
    registerPlugin<Lightly::Decoration>();
    registerPlugin<Lightly::Button>();
)

namespace
{
    struct ShadowParams {
        ShadowParams()
            : offset(QPoint(0, 0))
            , radius(0)
            , opacity(0) {}

        ShadowParams(const QPoint &offset, int radius, qreal opacity)
            : offset(offset)
            , radius(radius)
            , opacity(opacity) {}

        QPoint offset;
        int radius;
        qreal opacity;
    };

    struct CompositeShadowParams {
        CompositeShadowParams() = default;

        CompositeShadowParams(
                const QPoint &offset,
                const ShadowParams &shadow1,
                const ShadowParams &shadow2)
            : offset(offset)
            , shadow1(shadow1)
            , shadow2(shadow2) {}

        bool isNone() const {
            return qMax(shadow1.radius, shadow2.radius) == 0;
        }

        QPoint offset;
        ShadowParams shadow1;
        ShadowParams shadow2;
    };

    const CompositeShadowParams s_shadowParams[] = {
        // None
        CompositeShadowParams(),
        // Small
        CompositeShadowParams(
            QPoint(0, 4),
            ShadowParams(QPoint(0, 0), 16, 1),
            ShadowParams(QPoint(0, -2), 8, 0.4)),
        // Medium
        CompositeShadowParams(
            QPoint(0, 8),
            ShadowParams(QPoint(0, 0), 32, 0.9),
            ShadowParams(QPoint(0, -4), 16, 0.3)),
        // Large
        CompositeShadowParams(
            QPoint(0, 12),
            ShadowParams(QPoint(0, 0), 48, 0.8),
            ShadowParams(QPoint(0, -6), 24, 0.2)),
        // Very large
        CompositeShadowParams(
            QPoint(0, 16),
            ShadowParams(QPoint(0, 0), 64, 0.7),
            ShadowParams(QPoint(0, -8), 32, 0.1)),
    };

    inline CompositeShadowParams lookupShadowParams(int size)
    {
        switch (size) {
        case Lightly::InternalSettings::ShadowNone:
            return s_shadowParams[0];
        case Lightly::InternalSettings::ShadowSmall:
            return s_shadowParams[1];
        case Lightly::InternalSettings::ShadowMedium:
            return s_shadowParams[2];
        case Lightly::InternalSettings::ShadowLarge:
            return s_shadowParams[3];
        case Lightly::InternalSettings::ShadowVeryLarge:
            return s_shadowParams[4];
        default:
            // Fallback to the Large size.
            return s_shadowParams[3];
        }
    }
}

namespace Lightly
{

    using KDecoration3::ColorRole;
    using KDecoration3::ColorGroup;

    //________________________________________________________________
    static int g_sDecoCount = 0;
    static int g_shadowSizeEnum = InternalSettings::ShadowLarge;
    static int g_shadowStrength = 255;
    static QColor g_shadowColor = Qt::black;
    static std::shared_ptr<KDecoration3::DecorationShadow> g_sShadow;

    //________________________________________________________________
    Decoration::Decoration(QObject *parent, const QVariantList &args)
        : KDecoration3::Decoration(parent, args)
        , m_animation( new QVariantAnimation( this ) )
    {
        g_sDecoCount++;
    }

    //________________________________________________________________
    Decoration::~Decoration()
    {
        g_sDecoCount--;
        if (g_sDecoCount == 0) {
            // last deco destroyed, clean up shadow
            g_sShadow.reset();
        }

        deleteSizeGrip();

    }

    //________________________________________________________________
    void Decoration::setOpacity( qreal value )
    {
        if( m_opacity == value ) return;
        m_opacity = value;
        update();

        if( m_sizeGrip ) m_sizeGrip->update();
    }

    //________________________________________________________________
    QColor Decoration::titleBarColor() const
    {

        const auto c = window();
        if( hideTitleBar() ) return c->color( ColorGroup::Inactive, ColorRole::TitleBar );
        else if( m_animation->state() == QAbstractAnimation::Running )
        {
            return KColorUtils::mix(
                c->color( ColorGroup::Inactive, ColorRole::TitleBar ),
                c->color( ColorGroup::Active, ColorRole::TitleBar ),
                m_opacity );
        } else return c->color( c->isActive() ? ColorGroup::Active : ColorGroup::Inactive, ColorRole::TitleBar );

    }

    //________________________________________________________________
    QColor Decoration::outlineColor() const
    {

        const auto c = window();
        if( !m_internalSettings->drawTitleBarSeparator() ) return QColor();
        if( m_animation->state() == QAbstractAnimation::Running )
        {
            QColor color( c->palette().color( QPalette::Highlight ) );
            color.setAlpha( color.alpha()*m_opacity );
            return color;
        } else if( c->isActive() ) return c->palette().color( QPalette::Highlight );
        else return QColor();
    }

    //________________________________________________________________
    QColor Decoration::fontColor() const
    {

        const auto c = window();
        if( m_animation->state() == QAbstractAnimation::Running )
        {
            return KColorUtils::mix(
                c->color( ColorGroup::Inactive, ColorRole::Foreground ),
                c->color( ColorGroup::Active, ColorRole::Foreground ),
                m_opacity );
        } else return  c->color( c->isActive() ? ColorGroup::Active : ColorGroup::Inactive, ColorRole::Foreground );

    }

    //________________________________________________________________
    bool Decoration::init()
    {
        const auto c = window();

        // active state change animation
        // It is important start and end value are of the same type, hence 0.0 and not just 0
        m_animation->setStartValue( 0.0 );
        m_animation->setEndValue( 1.0 );
        m_animation->setEasingCurve( QEasingCurve::InOutQuad );
        connect(m_animation, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
            setOpacity(value.toReal());
        });

        reconfigure();
        updateTitleBar();
        auto s = settings();
        connect(s.get(), &KDecoration3::DecorationSettings::borderSizeChanged, this, &Decoration::recalculateBorders);

        // a change in font might cause the borders to change
        connect(s.get(), &KDecoration3::DecorationSettings::fontChanged, this, &Decoration::recalculateBorders);
        connect(s.get(), &KDecoration3::DecorationSettings::spacingChanged, this, &Decoration::recalculateBorders);

        // buttons
        connect(s.get(), &KDecoration3::DecorationSettings::spacingChanged, this, &Decoration::updateButtonsGeometryDelayed);
        connect(s.get(), &KDecoration3::DecorationSettings::decorationButtonsLeftChanged, this, &Decoration::updateButtonsGeometryDelayed);
        connect(s.get(), &KDecoration3::DecorationSettings::decorationButtonsRightChanged, this, &Decoration::updateButtonsGeometryDelayed);

        // full reconfiguration
        connect(s.get(), &KDecoration3::DecorationSettings::reconfigured, this, &Decoration::reconfigure);
        connect(s.get(), &KDecoration3::DecorationSettings::reconfigured, SettingsProvider::self(), &SettingsProvider::reconfigure, Qt::UniqueConnection );
        connect(s.get(), &KDecoration3::DecorationSettings::reconfigured, this, &Decoration::updateButtonsGeometryDelayed);

        connect(c, &KDecoration3::DecoratedWindow::adjacentScreenEdgesChanged, this, &Decoration::recalculateBorders);
        connect(c, &KDecoration3::DecoratedWindow::maximizedHorizontallyChanged, this, &Decoration::recalculateBorders);
        connect(c, &KDecoration3::DecoratedWindow::maximizedVerticallyChanged, this, &Decoration::recalculateBorders);
        connect(c, &KDecoration3::DecoratedWindow::shadedChanged, this, &Decoration::recalculateBorders);
        connect(c, &KDecoration3::DecoratedWindow::captionChanged, this,
            [this]()
            {
                // update the caption area
                update(titleBar());
            }
        );

        connect(c, &KDecoration3::DecoratedWindow::activeChanged, this, &Decoration::updateAnimationState);
        connect(c, &KDecoration3::DecoratedWindow::widthChanged, this, &Decoration::updateTitleBar);
        connect(c, &KDecoration3::DecoratedWindow::adjacentScreenEdgesChanged, this, &Decoration::updateTitleBar);
        connect(c, &KDecoration3::DecoratedWindow::maximizedChanged, this, &Decoration::updateTitleBar);
        connect(this, &KDecoration3::Decoration::bordersChanged, this, &Decoration::updateTitleBar);

        connect(c, &KDecoration3::DecoratedWindow::widthChanged, this, &Decoration::updateButtonsGeometry);
        connect(c, &KDecoration3::DecoratedWindow::maximizedChanged, this, &Decoration::updateButtonsGeometry);
        connect(c, &KDecoration3::DecoratedWindow::adjacentScreenEdgesChanged, this, &Decoration::updateButtonsGeometry);
        connect(c, &KDecoration3::DecoratedWindow::shadedChanged, this, &Decoration::updateButtonsGeometry);
        connect(c, &KDecoration3::DecoratedWindow::nextScaleChanged, this, &Decoration::updateScale);

        createButtons();
        createShadow();

        return true;
    }

    //________________________________________________________________
    void Decoration::updateTitleBar()
    {
        auto s = settings();
        auto c = window();
        const bool maximized = isMaximized();
        const qreal width =  maximized ? c->width() : c->width() - 2*s->largeSpacing()*Metrics::TitleBar_SideMargin;
        const qreal height = maximized ? borderTop() : borderTop() - s->smallSpacing()*Metrics::TitleBar_TopMargin;
        const qreal x = maximized ? 0 : s->largeSpacing()*Metrics::TitleBar_SideMargin;
        const qreal y = maximized ? 0 : s->smallSpacing()*Metrics::TitleBar_TopMargin;
        setTitleBar(QRectF(x, y, width, height));
    }

    //________________________________________________________________
    void Decoration::updateAnimationState()
    {
        if( m_internalSettings->animationsEnabled() )
        {

            const auto c = window();
            m_animation->setDirection( c->isActive() ? QAbstractAnimation::Forward : QAbstractAnimation::Backward );
            if( m_animation->state() != QAbstractAnimation::Running ) m_animation->start();

        } else {

            update();

        }
    }

    //________________________________________________________________
    void Decoration::updateSizeGripVisibility()
    {
        const auto c = window();
        if( m_sizeGrip )
        { m_sizeGrip->setVisible( c->isResizeable() && !isMaximized() && !c->isShaded() ); }
    }

    //________________________________________________________________
    qreal Decoration::borderSize(bool bottom, qreal scale) const
    {
        const qreal pixelSize = KDecoration3::pixelSize(scale);
        const qreal baseSize = std::max<qreal>(pixelSize, KDecoration3::snapToPixelGrid(settings()->smallSpacing(), scale));
        if( m_internalSettings && (m_internalSettings->mask() & BorderSize ) )
        {
            switch (m_internalSettings->borderSize()) {
                case InternalSettings::BorderNone: return 0;
                case InternalSettings::BorderNoSides: return bottom ? KDecoration3::snapToPixelGrid(std::max(4.0, baseSize), scale) : 0;
                default:
                case InternalSettings::BorderTiny: return bottom ? KDecoration3::snapToPixelGrid(std::max(4.0, baseSize), scale) : baseSize;
                case InternalSettings::BorderNormal: return baseSize*2;
                case InternalSettings::BorderLarge: return baseSize*3;
                case InternalSettings::BorderVeryLarge: return baseSize*4;
                case InternalSettings::BorderHuge: return baseSize*5;
                case InternalSettings::BorderVeryHuge: return baseSize*6;
                case InternalSettings::BorderOversized: return baseSize*10;
            }

        } else {

            switch (settings()->borderSize()) {
                case KDecoration3::BorderSize::None: return 0;
                case KDecoration3::BorderSize::NoSides: return bottom ? KDecoration3::snapToPixelGrid(std::max(4.0, baseSize), scale) : 0;
                default:
                case KDecoration3::BorderSize::Tiny: return bottom ? KDecoration3::snapToPixelGrid(std::max(4.0, baseSize), scale) : baseSize;
                case KDecoration3::BorderSize::Normal: return baseSize*2;
                case KDecoration3::BorderSize::Large: return baseSize*3;
                case KDecoration3::BorderSize::VeryLarge: return baseSize*4;
                case KDecoration3::BorderSize::Huge: return baseSize*5;
                case KDecoration3::BorderSize::VeryHuge: return baseSize*6;
                case KDecoration3::BorderSize::Oversized: return baseSize*10;

            }

        }
    }

    //________________________________________________________________
    void Decoration::reconfigure()
    {

        m_internalSettings = SettingsProvider::self()->internalSettings( this );

        // animation
        m_animation->setDuration( m_internalSettings->animationsDuration() );

        // borders
        recalculateBorders();

        // shadow
        createShadow();

        // size grip
        if( hasNoBorders() && m_internalSettings->drawSizeGrip() ) createSizeGrip();
        else deleteSizeGrip();

    }

    //________________________________________________________________
    QMarginsF Decoration::bordersFor(qreal scale) const
    {
        const auto c = window();
        auto s = settings();

        // left, right and bottom borders
        const qreal left   = isLeftEdge() ? 0 : borderSize();
        const qreal right  = isRightEdge() ? 0 : borderSize();
        const qreal bottom = (c->isShaded() || isBottomEdge()) ? 0 : borderSize(true);

        qreal top = 0;
        if( hideTitleBar() ) top = bottom;
        else {

            QFontMetrics fm(s->font());
            top += KDecoration3::snapToPixelGrid(std::max(fm.height(), buttonHeight()), scale);

            // padding below
            // extra pixel is used for the active window outline
            const int baseSize = s->smallSpacing();
            top += KDecoration3::snapToPixelGrid(baseSize * Metrics::TitleBar_BottomMargin + 1, scale);

            // padding above
            top += KDecoration3::snapToPixelGrid(baseSize * Metrics::TitleBar_TopMargin, scale);

        }
        return QMarginsF(left, top, right, bottom);
    }
    
    void Decoration::recalculateBorders()
    {
        setBorders(bordersFor(window()->nextScale()));

        // extended sizes
        const qreal extSize = KDecoration3::snapToPixelGrid(settings()->largeSpacing(), window()->nextScale());
        qreal extSides = 0;
        qreal extBottom = 0;
        if( hasNoBorders() )
        {
            if( !isMaximizedHorizontally() ) extSides = extSize;
            if( !isMaximizedVertically() ) extBottom = extSize;

        } else if( hasNoSideBorders() && !isMaximizedHorizontally() ) {

            extSides = extSize;

        }

        setResizeOnlyBorders(QMarginsF(extSides, 0, extSides, extBottom));
    }

    //________________________________________________________________
    void Decoration::createButtons()
    {
        m_leftButtons = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Left, this, &Button::create);
        m_rightButtons = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Right, this, &Button::create);
        updateButtonsGeometry();
    }

    //________________________________________________________________
    void Decoration::updateButtonsGeometryDelayed()
    { QTimer::singleShot( 0, this, &Decoration::updateButtonsGeometry ); }

    //________________________________________________________________
    void Decoration::updateButtonsGeometry()
    {
        const auto s = settings();

        // adjust button position
        //const int bHeight = captionHeight() + (isTopEdge() ? s->smallSpacing()*Metrics::TitleBar_TopMargin:0);
        const int bWidth = buttonHeight();
        const int verticalOffset = (isTopEdge() ? s->smallSpacing()*Metrics::TitleBar_TopMargin:0); //+ (captionHeight()-buttonHeight())/2;
        const int bHeight = buttonHeight() + verticalOffset;
        const auto buttonList = m_leftButtons->buttons() + m_rightButtons->buttons();
        for(const QPointer<KDecoration3::DecorationButton> button : buttonList)
        {
            auto btn = static_cast<Button *>(button.get());
            btn->setGeometry( QRectF( QPoint( 0, 0 ), QSizeF( bWidth, bHeight ) ) );
            btn->setOffset( QPointF( 0, verticalOffset ) );
            btn->setIconSize( QSize( bWidth, bWidth ) );
        }

        // left buttons
        if( !m_leftButtons->buttons().isEmpty() )
        {

            // spacing
            m_leftButtons->setSpacing(s->smallSpacing()*Metrics::TitleBar_ButtonSpacing);

            // padding
            const int vPadding = isTopEdge() ? 0 : s->smallSpacing()*Metrics::TitleBar_TopMargin;
            const int hPadding = s->smallSpacing()*Metrics::TitleBar_SideMargin;
            if( isLeftEdge() )
            {
                // add offsets on the side buttons, to preserve padding, but satisfy Fitts law
                auto button = static_cast<Button*>( m_leftButtons->buttons().front() );
                button->setGeometry( QRectF( QPoint( 0, 0 ), QSizeF( bWidth + hPadding, bHeight ) ) );
                button->setFlag( Button::FlagFirstInList );
                button->setHorizontalOffset( hPadding );

                m_leftButtons->setPos(QPointF(0, vPadding));

            } else m_leftButtons->setPos(QPointF(hPadding + borderLeft(), vPadding));

        }

        // right buttons
        if( !m_rightButtons->buttons().isEmpty() )
        {

            // spacing
            m_rightButtons->setSpacing(s->smallSpacing()*Metrics::TitleBar_ButtonSpacing);

            // padding
            const int vPadding = isTopEdge() ? 0 : s->smallSpacing()*Metrics::TitleBar_TopMargin;
            const int hPadding = s->smallSpacing()*Metrics::TitleBar_SideMargin;
            if( isRightEdge() )
            {

                auto button = static_cast<Button*>( m_rightButtons->buttons().back() );
                button->setGeometry( QRectF( QPoint( 0, 0 ), QSizeF( bWidth + hPadding, bHeight ) ) );
                button->setFlag( Button::FlagLastInList );

                m_rightButtons->setPos(QPointF(size().width() - m_rightButtons->geometry().width(), vPadding));

            } else m_rightButtons->setPos(QPointF(size().width() - m_rightButtons->geometry().width() - hPadding - borderRight(), vPadding));

        }

        update();

    }

    //________________________________________________________________
    void Decoration::paint(QPainter *painter, const QRectF &repaintRegion)
    {
        // TODO: optimize based on repaintRegion
        auto c = window();
        auto s = settings();

        // paint background
        if( !c->isShaded() )
        {
            painter->fillRect(rect(), Qt::transparent);
            painter->save();
            painter->setRenderHint(QPainter::Antialiasing);
            painter->setPen(Qt::NoPen);
            painter->setBrush( c->color( c->isActive() ? ColorGroup::Active : ColorGroup::Inactive, ColorRole::Frame ) );

            // clip away the top part
            if( !hideTitleBar() ) painter->setClipRect(QRectF(0, borderTop(), size().width(), size().height() - borderTop()), Qt::IntersectClip);

            if( s->isAlphaChannelSupported() ) painter->drawRoundedRect(rect(), m_internalSettings->cornerRadius(), m_internalSettings->cornerRadius());
            else painter->drawRect( rect() );

            painter->restore();
        }

        if( !hideTitleBar() ) paintTitleBar(painter, repaintRegion);

        if( hasBorders() && !s->isAlphaChannelSupported() )
        {
            painter->save();
            painter->setRenderHint(QPainter::Antialiasing, false);
            painter->setBrush( Qt::NoBrush );
            painter->setPen( c->isActive() ?
                c->color( ColorGroup::Active, ColorRole::TitleBar ):
                c->color( ColorGroup::Inactive, ColorRole::Foreground ) );

            painter->drawRect( rect().adjusted( 0, 0, -1, -1 ) );
            painter->restore();
        }

    }

    //________________________________________________________________
    void Decoration::paintTitleBar(QPainter *painter, const QRectF &repaintRegion)
    {
        const auto c = window();
        const QRectF titleRect(QPoint(0, 0), QSizeF(size().width(), borderTop()));

        if ( !titleRect.intersects(repaintRegion) ) return;

        painter->save();
        painter->setPen(Qt::NoPen);

        // render a linear gradient on title area
        if( c->isActive() && m_internalSettings->drawBackgroundGradient() )
        {

            const QColor titleBarColor( this->titleBarColor() );
            QLinearGradient gradient( 0, 0, 0, titleRect.height() );
            gradient.setColorAt(0.0, titleBarColor.lighter( 120 ) );
            gradient.setColorAt(0.8, titleBarColor);
            painter->setBrush(gradient);

        } else {

            painter->setBrush( titleBarColor() );

        }

        auto s = settings();
        if( isMaximized() || !s->isAlphaChannelSupported() )
        {

            painter->drawRect(titleRect);
            
            // top highlight
            if( qGray(this->titleBarColor().rgb()) < 130 && m_internalSettings->drawHighlight() ) {
                painter->setPen(QColor(255, 255, 255, 30));
                painter->drawLine(titleRect.topLeft(), titleRect.topRight());
            }

        } else if( c->isShaded() ) {

            painter->drawRoundedRect(titleRect, m_internalSettings->cornerRadius(), m_internalSettings->cornerRadius());

        } else {

            painter->setClipRect(titleRect, Qt::IntersectClip);
            
            // the rect is made a little bit larger to be able to clip away the rounded corners at the bottom and sides
            QRectF copy ( titleRect.adjusted(
                isLeftEdge() ? -m_internalSettings->cornerRadius():0,
                isTopEdge() ? -m_internalSettings->cornerRadius():0,
                isRightEdge() ? m_internalSettings->cornerRadius():0,
                m_internalSettings->cornerRadius()) );
            
            
            painter->drawRoundedRect(copy, m_internalSettings->cornerRadius(), m_internalSettings->cornerRadius());
            
            // top highlight
            if( qGray(this->titleBarColor().rgb()) < 130 && m_internalSettings->drawHighlight() ) {
                QPixmap pix = QPixmap( copy.width(), copy.height() );
                pix.fill( Qt::transparent );
        
                QPainter p(&pix);
                p.setRenderHint( QPainter::Antialiasing );
                p.setPen(Qt::NoPen);
                p.setBrush(QColor(255, 255, 255, 30));
                p.drawRoundedRect(copy, m_internalSettings->cornerRadius(), m_internalSettings->cornerRadius());
                
                p.setBrush(Qt::black);
                p.setCompositionMode(QPainter::CompositionMode_DestinationOut);
                p.drawRoundedRect(copy.adjusted(0, 1, 0, 0), m_internalSettings->cornerRadius(), m_internalSettings->cornerRadius());
                
                painter->drawPixmap(copy, pix, repaintRegion);//Not sure why, but it didn't work with two arguments
            }

        }

        const QColor outlineColor( this->outlineColor() );
        if( !c->isShaded() && outlineColor.isValid() )
        {
            // outline
            painter->setRenderHint( QPainter::Antialiasing, false );
            painter->setBrush( Qt::NoBrush );
            painter->setPen( outlineColor );
            painter->drawLine( titleRect.bottomLeft(), titleRect.bottomRight() );
        }

        painter->restore();

        // draw caption
        painter->setFont(s->font());
        painter->setPen( fontColor() );
        const auto cR = captionRect();
        const QString caption = painter->fontMetrics().elidedText(c->caption(), Qt::ElideMiddle, cR.first.width());
        painter->drawText(cR.first, cR.second | Qt::TextSingleLine, caption);

        // draw all buttons
        m_leftButtons->paint(painter, repaintRegion);
        m_rightButtons->paint(painter, repaintRegion);
    }

    //________________________________________________________________
    int Decoration::buttonHeight() const
    {
        const int baseSize = settings()->gridUnit();
        switch( m_internalSettings->buttonSize() )
        {
            case InternalSettings::ButtonTiny: return baseSize;
            case InternalSettings::ButtonSmall: return baseSize*1.5;
            default:
            case InternalSettings::ButtonDefault: return baseSize*2;
            case InternalSettings::ButtonLarge: return baseSize*2.5;
            case InternalSettings::ButtonVeryLarge: return baseSize*3.5;
        }

    }

    void Decoration::onTabletModeChanged(bool mode)
    {
        m_tabletMode = mode;
        Q_EMIT tabletModeChanged();

        recalculateBorders();
        updateButtonsGeometry();
    }
    
    //________________________________________________________________
    qreal Decoration::captionHeight() const
    { return hideTitleBar() ? borderTop() : borderTop() - settings()->smallSpacing()*(Metrics::TitleBar_BottomMargin + Metrics::TitleBar_TopMargin ) - 1; }

    //________________________________________________________________
    QPair<QRectF,Qt::Alignment> Decoration::captionRect() const
    {
        if( hideTitleBar() ) return qMakePair( QRectF(), Qt::AlignCenter );
        else {

            auto c = window();
            const qreal leftOffset = KDecoration3::snapToPixelGrid(m_leftButtons->buttons().isEmpty() ? Metrics::TitleBar_SideMargin * settings()->smallSpacing()
                                                                         : m_leftButtons->geometry().x() + m_leftButtons->geometry().width()
                                              + Metrics::TitleBar_SideMargin * settings()->smallSpacing(), c->scale());

            const qreal rightOffset = KDecoration3::snapToPixelGrid(m_rightButtons->buttons().isEmpty() ? Metrics::TitleBar_SideMargin * settings()->smallSpacing()
                                                                                                : size().width() - m_rightButtons->geometry().x()
                                                                    + Metrics::TitleBar_SideMargin * settings()->smallSpacing(), c->scale());

            const qreal yOffset = KDecoration3::snapToPixelGrid(settings()->smallSpacing() * Metrics::TitleBar_TopMargin, c->scale());
            const QRectF maxRect( leftOffset, yOffset, size().width() - leftOffset - rightOffset, captionHeight() );

            switch( m_internalSettings->titleAlignment() )
            {
                case InternalSettings::AlignLeft:
                return qMakePair( maxRect, Qt::AlignVCenter|Qt::AlignLeft );

                case InternalSettings::AlignRight:
                return qMakePair( maxRect, Qt::AlignVCenter|Qt::AlignRight );

                case InternalSettings::AlignCenter:
                return qMakePair( maxRect, Qt::AlignCenter );

                default:
                case InternalSettings::AlignCenterFullWidth:
                {

                    // full caption rect
                    const QRectF fullRect = QRect( 0, yOffset, size().width(), captionHeight() );
                    QRectF boundingRect( settings()->fontMetrics().boundingRect( c->caption()).toRect() );

                    // text bounding rect
                    boundingRect.setTop( yOffset );
                    boundingRect.setHeight( captionHeight() );
                    boundingRect.moveLeft( ( size().width() - boundingRect.width() )/2 );

                    if( boundingRect.left() < leftOffset ) return qMakePair( maxRect, Qt::AlignVCenter|Qt::AlignLeft );
                    else if( boundingRect.right() > size().width() - rightOffset ) return qMakePair( maxRect, Qt::AlignVCenter|Qt::AlignRight );
                    else return qMakePair(fullRect, Qt::AlignCenter);

                }

            }

        }

    }

    //________________________________________________________________
    void Decoration::createShadow()
    {
        if (!g_sShadow
                ||g_shadowSizeEnum != m_internalSettings->shadowSize()
                || g_shadowStrength != m_internalSettings->shadowStrength()
                || g_shadowColor != m_internalSettings->shadowColor())
        {
            g_shadowSizeEnum = m_internalSettings->shadowSize();
            g_shadowStrength = m_internalSettings->shadowStrength();
            g_shadowColor = m_internalSettings->shadowColor();

            const CompositeShadowParams params = lookupShadowParams(g_shadowSizeEnum);
            if (params.isNone()) {
                g_sShadow.reset();
                setShadow(g_sShadow);
                return;
            }

            auto withOpacity = [](const QColor &color, qreal opacity) -> QColor {
                QColor c(color);
                c.setAlphaF(opacity);
                return c;
            };

            const QSize boxSize = BoxShadowRenderer::calculateMinimumBoxSize(params.shadow1.radius)
                .expandedTo(BoxShadowRenderer::calculateMinimumBoxSize(params.shadow2.radius));

            BoxShadowRenderer shadowRenderer;
            shadowRenderer.setBorderRadius(m_internalSettings->cornerRadius() + 0.5);
            shadowRenderer.setBoxSize(boxSize);
            shadowRenderer.setDevicePixelRatio(1.0); // TODO: Create HiDPI shadows?

            const qreal strength = static_cast<qreal>(g_shadowStrength) / 255.0;
            shadowRenderer.addShadow(params.shadow1.offset, params.shadow1.radius,
                withOpacity(g_shadowColor, params.shadow1.opacity * strength));
            shadowRenderer.addShadow(params.shadow2.offset, params.shadow2.radius,
                withOpacity(g_shadowColor, params.shadow2.opacity * strength));

            QImage shadowTexture = shadowRenderer.render();

            QPainter painter(&shadowTexture);
            painter.setRenderHint(QPainter::Antialiasing);

            const QRectF outerRect = shadowTexture.rect();

            QRectF boxRect(QPoint(0, 0), boxSize);
            boxRect.moveCenter(outerRect.center());

            const QMarginsF padding = QMargins(
                boxRect.left() - outerRect.left() - Metrics::Shadow_Overlap - params.offset.x(),
                boxRect.top() - outerRect.top() - Metrics::Shadow_Overlap - params.offset.y(),
                outerRect.right() - boxRect.right() - Metrics::Shadow_Overlap + params.offset.x(),
                outerRect.bottom() - boxRect.bottom() - Metrics::Shadow_Overlap + params.offset.y());
            const QRectF innerRect = outerRect - padding;
            
            // Draw outline.
            painter.setPen(withOpacity(g_shadowColor, 0.4 * strength));
            painter.setBrush(Qt::NoBrush);
            painter.setCompositionMode(QPainter::CompositionMode_SourceOver);
            painter.drawRoundedRect(
                innerRect,
                m_internalSettings->cornerRadius() - 0.5,
                m_internalSettings->cornerRadius() - 0.5);

            // Mask out inner rect.
            painter.setPen(Qt::NoPen);
            painter.setBrush(Qt::black);
            painter.setCompositionMode(QPainter::CompositionMode_DestinationOut);
            painter.drawRoundedRect(
                innerRect,
                m_internalSettings->cornerRadius() + 0.5,
                m_internalSettings->cornerRadius() + 0.5);


            painter.end();

            g_sShadow = std::make_shared<KDecoration3::DecorationShadow>();
            g_sShadow->setPadding(padding);
            g_sShadow->setInnerShadowRect(QRectF(outerRect.center(), QSizeF(1, 1)));
            g_sShadow->setShadow(shadowTexture);
        }

        setShadow(g_sShadow);
    }

    //_________________________________________________________________
    void Decoration::createSizeGrip()
    {

        // do nothing if size grip already exist
        if( m_sizeGrip ) return;

        #if LIGHTLY_HAVE_X11
        if( !QX11Info::isPlatformX11() ) return;

        // access window
        auto c = window();
        if( !c ) return;

        if( c->windowId() != 0 )
        {
            m_sizeGrip = new SizeGrip( this );
            connect( c, &KDecoration3::DecoratedWindow::maximizedChanged, this, &Decoration::updateSizeGripVisibility );
            connect( c, &KDecoration3::DecoratedWindow::shadedChanged, this, &Decoration::updateSizeGripVisibility );
            connect( c, &KDecoration3::DecoratedWindow::resizeableChanged, this, &Decoration::updateSizeGripVisibility );
        }
        #endif

    }

    //_________________________________________________________________
    void Decoration::deleteSizeGrip()
    {
        if( m_sizeGrip )
        {
            m_sizeGrip->deleteLater();
            m_sizeGrip = nullptr;
        }
    }
    
    void Decoration::setScaledCornerRadius()
    {
        // On X11, the smallSpacing value is used for scaling.
        // On Wayland, this value has constant factor of 2.
        // Removing it will break radius scaling on X11.
        m_scaledCornerRadius = KDecoration3::snapToPixelGrid(Metrics::Frame_FrameRadius * settings()->smallSpacing(), window()->scale());
    }
    
    void Decoration::updateScale()
    {
        setScaledCornerRadius();
        recalculateBorders();
    }

} // namespace


#include "lightlydecoration.moc"
