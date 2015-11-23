---
layout: post
title: Construindo um UIButton
---

O [`UIButton`](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIButton_Class/) é uma classe extensamente utilizada, muito testada e configurável, então:

> Porque alguém em sã consciência perderia tempo fazendo um botão?

Eu acredito o objetivo didático seria justificativa suficiente, algo como o [Mike Ash](https://twitter.com/mikeash) faz com alguma frequência em seu [blog](https://mikeash.com/pyblog/), não é o caso. Por *simplicidade* vamos assumir que o problema não está na minha sanidade, mas em um desconforto ao customizar um botão.

Com frequência os botões são usados para iniciar requisições à servidores, no mundo real isso não é instantâneo e o usuário deve (ou deveria) ser *entretido* de alguma maneira enquanto a resposta dessa requisição não chega.

Existem inúmeras maneiras de fazer isso, não vou discutir todas porque não cabe no escopo desse artigo, só digo para não colocar um *spinner* bem no meio da tela impedindo o usuário de interagir com seu *app*. Uma maneira que gosto bastante é de apresentar o estado da requisição dentro do botão que a iniciou. Mas para isso é preciso ter um botão que tenha esse novo estado. Adaptar (*cof* *hackear* *cof*) um UIButton não me pareceu uma maneira honesta, vou discutir isso em um artigo específico, então decidi construir um botão que replica o [`UIButton`](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIButton_Class/) e depois adicionar o novo estado, o que não é uma tarefa fácil, mas muito instrutiva. A idéia é reproduzir o comportamento de um botão do tipo `UIButtonType.System`. Além disso me pareceu uma boa oportunidade de exercitar um pouco meu `Swift`.

O `UIButton` tem muitos elementos: 

* `titleLabel`
* `attributedTitle`
* `titleColor`
* `titleShadow`
* `image`
* `backgroundImage`
* `tintColor`

estados:

* `UIControlState.Normal`
* `UIControlState.Highlighted`
* `UIControlState.Disabled`
* `UIControlState.Selected`

E outros detalhes não óbvios como reagir à `tintAdjustmentMode`, acessibilidade, `UIAppearance`, animações, `contentEdgeInsets`, `titleEdgeInsets`, `imageEdgeInsets ` e outras coisas que eu ainda não descobri, então decidi limitar os requisitos dessa versão 1.0. Uma das primeiras decisões é que o `Button` deve ser subclasse do `UIControl`, suponho que isso deve facilitar a vida. A interface, se é que existe isso em `Swift`, deve ser algo assim:

{% highlight swift %}
public class Button : UIControl {
    
    public var enabled: Bool

    public let titleLabel: UILabel
    public func titleForState(state: UIControlState) -> String?
    public func setTitle(title: String?, forState state: UIControlState)
    public func titleColorForState(state: UIControlState) -> UIColor?
    public func setTitleColor(color: UIColor?, forState state: UIControlState)

    public let imageView: UIImageView
    public func imageForState(state: UIControlState) -> UIImage?
    public func setImage(image: UIImage?, forState state: UIControlState)

    public func backgroundImageForState(state: UIControlState) -> UIImage?
    public func setBackgroundImage(image: UIImage?, forState state: UIControlState)
    
    public func addTarget(target: AnyObject?, action action: Selector, forControlEvents controlEvents: UIControlEvents)
}
{% endhighlight %}

Vemos que os *insets* estão de fora, a parte de acessibilidade também vou deixar para a próxima versão, junto com `UIAppearance`. Uma coisa que eu gostaria de fazer mas me pareceu bem mais complicado do que eu imaginava são as animações, especialmente a do `titleLabel`:

![UIButton label animation](/public/imgs/construindo-um-uibutton-01.gif)

Note que nunca os dois textos aparecem ao mesmo tempo, o texto do estado `Normal` desaparece e depois o `Highlighted` aparece, mas porque esse tempo sem texto nenhum? 
Nas minhas tentativas de animar a transição percebi que a diferença no tamanho do texto obrigua o um redimensionamento da *label*, e ai tudo vai para o brejo. Uma maneira de evitar é colocar esse tempo em "branco". Fuçando com o [Reveal](http://revealapp.com) descobri que o *label* do `UIButton` não é uma `UILabel` mas uma `UIButtonLabel`, uma classe que não é pública e deve resolver esses detalhes das animações ¯\\\_(ツ)_/¯. Uma outra complicação é que essa animação pode ser cancelada, ou alterada, antes de seu fim, dependendo do tempo de duração do toque. Acho que isso daria assunto para um artigo inteiro!

A hierarquia de *views* consiste de uma `UIImageView` que vai conter a `backgrondImage`, uma `contentView` que contém `UIImageView` e `UILabel` como mostra a imagem:

![Button view hierarchy](/public/imgs/construindo-um-uibutton-02.png)

O Layout foi feito usando `Autolayout` e não vou entrar em mais detalhes porque ele foi estruturado para não depender do conteúdo do botão, quem se interessar pode dar uma olhada no projeto do github.

O `UIButton` tem alguns comportamentos específicos para cada um de suas "propriedades":

* `titleLabel`, se não for definida uma *string* para um estado específico a do estado `.Normal` é utilizada. O estado `.Highlighted` causa um comportamento diferente quando este não tem uma *string* definda e nem uma `titleColor`, o `alpha` do `titleLabel` passa a ser `0.2`, causando o efeito de selecionado;
* `titleColor`, se não for definida uma cor para um estado específico a do estado `.Normal` é utilizada. Quando nenhuma cor específica for definida as coisa ficam interessantes. No estado `.Normal` e `.Highlighted` é utilizada a `tintColor`, e quanto ela muda, por exemplo devido a alteração no `tintAdjustmentMode`, isso é respeitado. Esse comportamento é o que faz com que o botão fique "cinza" quando aparece um *popup*. Quando o estado é 
`.Disabled` a cor é alterada para `UIColor(white: 0.4, alpha: 0.35)`, infelizmente não consegui achar uma cor do sistema que corresponda a esse padrão :-(
*  `image` e `backgroundImage`, se não for definida uma imagem para um estado específico a do estado `.Normal` é utilizado. No caso do estado `.Highlighted` não ter uma imagem, além de ser utilizada a do estado `.Normal` o `alpha` do elemento em questão passa a ser `0.2`;

Dividimos essa questão em dois problemas, primeiro como armazenar os valores das propriedades para cada estado e depois aplicar a lógica para cada propriedade.

A maneira mais simples de armazenar seria utilizando um dicionário:

{% highlight swift %}
private var titles = [UIControlState: String]()
private var titleColors = [UIControlState: UIColor]()
private var images = [UIControlState: UIImage]()
private var backgroundImages = [UIControlState: UIImage]()
{% endhighlight %}

Mas `UIControlState` não implementa o protocolo `Hashable`, isso é facilmente resolvido com uma `extension` que implementa o `hashValue` como o `Int(rawValue)` do protocolo `RawRepresentable` (esse "truque" fez `Swift` ganhar alguns pontos comigo):

{% highlight swift %}
extension UIControlState: Hashable {
    public var hashValue: Int {
        get {
            return Int(rawValue)
        }
    }
}
{% endhighlight %}

A implementação dos métodos públicos lidam com estados do `titleLabel` ficam bem simples:

{% highlight swift %}
public func titleForState(state: UIControlState) -> String? {
    return titles[state]
}

public func setTitle(title: String?, forState state: UIControlState) {
    if let title = title {
        titles[state] = title
    } else {
        titles.removeValueForKey(state)
    }

    updateUI()
}
{% endhighlight %}

Os métodos das outras propriedades tem exatamente a mesma lógica, o que vale notar aqui é a chamada `updateUI()`, esse método é o que atualiza as mudanças na tela e resolve grande parte do segundo problema:

{% highlight swift %}
private func updateUI() {
    let defaultState = UIControlState.Normal
    let state = self.state

    let title: String?
    let titleIsFallback: Bool
    (title, titleIsFallback) = getValeuIn(titles, forState: state, fallbackState: defaultState, fallbackValue: nil)

    let textColor: UIColor?
    let textColorIsFallback: Bool
    (textColor, textColorIsFallback) = getValeuIn(titleColors, forState: state, fallbackState: defaultState, fallbackValue: enabled ? tintColor : UIColor(white: 0.4, alpha: 0.35))

    let image: UIImage?
    let imageIsFallback: Bool
    (image, imageIsFallback) = getValeuIn(images, forState: state, fallbackState: defaultState, fallbackValue: nil)

    let backgroundImage: UIImage?
    let backgroundImageIsFallback: Bool
    (backgroundImage, backgroundImageIsFallback) = getValeuIn(backgroundImages, forState: state, fallbackState: defaultState, fallbackValue: nil)

    let textAlpha: CGFloat = highlighted && titleIsFallback && textColorIsFallback ? highlightedAlpha : normalAlpha
    let imageAlpha: CGFloat = highlighted && imageIsFallback ? highlightedAlpha : normalAlpha
    let backgroundImageAlpha: CGFloat = highlighted && backgroundImageIsFallback ? highlightedAlpha : normalAlpha

    titleLabel.text = title
    titleLabel.textColor = textColor
    titleLabel.alpha = textAlpha
    imageView.image = image
    imageView.alpha = imageAlpha
    backgroundImageView.image = backgroundImage
    backgroundImageView.alpha = backgroundImageAlpha
}
{% endhighlight %}

É um método extenso, o correto seria extrair a lógica de cada propriedade em métodos separados para poder testar somente a lógica, mas para uma primeira versão serve.

A lógica é feita em duas fases, na primeira é definido o valor da propriedade para o estado atual e se esse valor foi definido ou é padrão (*fallback*). Na segunda fase é definido o `alpha`,
no fim tudo é atualizado de uma só vez.

Um método genérico é usado na primeira fase: 

{% highlight swift %}
private func getValeuIn<T>(collection: [UIControlState: T], forState state: UIControlState, fallbackState defaultState: UIControlState, fallbackValue: T?) -> (T?, Bool) {
    let thing: T?
    let thingIsFallback: Bool

    if let aThing = collection[state] {
        thing = aThing
        thingIsFallback = false
    } else {
        thing = collection[defaultState] ?? fallbackValue
        thingIsFallback = true
    }

    return (thing, thingIsFallback)
}
{% endhighlight %}

O único comentários pertinente seria mais uma vez ponto para o `Swift` com *generics* e *tuples* (já não sinto tanta falta do `;`).

Para completar a atualização dos estado `.Disabled` é preciso fazer chamar `updateUI()` quando o `enabled` é chamado:

{% highlight swift %}
override public var enabled: Bool {
    didSet {
        updateUI()
    }
}
{% endhighlight %}

E o equivalente quando há uma mudança na `tintColor`:

{% highlight swift %}
override public func tintColorDidChange() {
    updateUI()
}
{% endhighlight %}

A atualização para o estado `.Highlighted` requer alterações no *tracking* do *touch*:

{% highlight swift %}
override public func beginTrackingWithTouch(touch: UITouch, withEvent event: UIEvent?) -> Bool {
    let track = super.beginTrackingWithTouch(touch, withEvent: event)
    updateWithTouch(touch)
    return track
}

override public func continueTrackingWithTouch(touch: UITouch, withEvent event: UIEvent?) -> Bool {
    let track = super.continueTrackingWithTouch(touch, withEvent: event)
    updateWithTouch(touch)
    return track
}

override public func endTrackingWithTouch(touch: UITouch?, withEvent event: UIEvent?) {
    super.endTrackingWithTouch(touch, withEvent: event)
    if let touch = touch {
        updateWithTouch(touch)
    }
}
{% endhighlight %}

O *highlight* depende do *touch* estar dentro da área do botão, a propriedade `touchInside` do `UIControl` é a ideal para saber isso, mas temos um problema. Ela só é atualizada quando o `beginTrackingWithTouch(_:withEvent:) -> Bool` retorna, como nosso método `updateWithTouch(_:)` é chamado antes do retorno temos que fazer um *workaround*:

{% highlight swift %}
private func updateWithTouch(touch: UITouch) {
    let point = touch.locationInView(self)
    let ended = touch.phase == .Ended

    // Workaround because touchInside inside is not true on beginTrackingWithTouch
    let insideTouch = pointInside(point, withEvent: nil)

    highlighted = ended ? false : insideTouch || touchInside

    updateUI()
}
{% endhighlight %}

Acho que com isso consegui cobrir os requisitos da versão 1.0 e deu para entender um pouco melhor o funcionamento do `UIButton`. Algumas propriedades ainda permanecem um mistério para mim, como o `adjustsImageWhenHighlighted`, que ao meu entendimento deveria habilitar e desabilitar a alteração do `alpha` quando falso, mas nos meus testes não consegui ver diferença. 

O [`Button`](https://github.com/diogot/LoadingButton/blob/Button/LoadingButton/Button.swift) pode ser encontrado no *branch* [Button](https://github.com/diogot/LoadingButton/tree/Button) do repositório [LoadingButton](https://github.com/diogot/LoadingButton). Criticas, sugestões e comentários são sempre bem vindos, é só me *pingar* no [@diogot](https://twitter.com/diogot) ou no [slack do iOS Dev BR](http://iosdevbr.herokuapp.com).

---

Uma dica para quem usa cores e não imagens como background e quer se beneficiar dos estados é criar um `UIImage` à partir de uma `UIColor` usando a seguinte *extension*:

{% highlight swift %}
extension UIColor {
    func image() -> UIImage {
        let frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 0)
        setFill()
        UIRectFill(frame)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }
}
{% endhighlight %}


---
Diogo Tridapalli <br />
[@diogot](https://twitter.com/diogot)
