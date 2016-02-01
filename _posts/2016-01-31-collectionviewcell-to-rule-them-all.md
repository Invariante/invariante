---
layout: post
title: Uma collection view cell to rule them all
---

Feliz ano novo, feliz *post* novo!

---

Um dia desses o caro [Vinicius](https://twitter.com/viniciusc70) estava [reclamando](https://twitter.com/viniciusc70/status/693172598981693441) da curva de aprendizado do [`UICollectionView`](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UICollectionView_class/), para quem não conhece é uma `UITableViewController` com esteroides.  
Você pode usar *layouts* customizados, transições de animações e muitas outras coisas que eu nem consigo imaginar. Por coincidência nesse mesmo dia eu estava implementando minha primeira `UICollectionView` em `Swift`. Nesse *post* não vou falar sobre essa classe mas de sobre suas células [`UICollectionViewCell`](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UICollectionViewCell_class/index.html).

No último mês venho *brigando* muito com [*generics*](https://github.com/apple/swift/blob/master/docs/Generics.rst) (ou [genéricos](https://github.com/CocoaHeadsBrasil/the-swift-programming-language-in-portuguese-br/blob/master/guia/genericos.md)) e consegui montar um exemplo interessante de uso aplicado à `UICollectionViewCell`. Esse classe não tem um *label* como a `UITableViewCell`, apenas uma `contentView`, isso dificulta exemplos mais simples pois implica que 100% da vezes você vai ter que customizar as células.

A `UICollectionViewCell` precisa de uma ou mais `UIView` que vão ser adicionadas à `contentView` para essa customização. Então seria natural que eu uma célula genérica dependesse desse tipo:

{% highlight swift %}
class CollectionViewCell<View: UIView>: UICollectionViewCell {

    private(set) var customView: View

    override init(frame: CGRect)
    {
        customView = View()

        super.init(frame: frame)
        
        contentView.addSubview(customView)
        
        customView.frame = contentView.bounds
        customView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    }
}
{% endhighlight %}

Nesse caso específico não vejo necessidade de usar `AutoLayout`. Aqui temos algo bem simples, na criação da célula uma instancia da `View` é criada adicionada à `contentView` de forma a ter sempre o seu tamanho.
Para customizar essa view em `collectionView(_: cellForItemAtIndexPath:)` seria apenas utilizar a referência a ela em `customView`.

Mas se começarmos a pensar na linha do `MVVM` seria interessante que essa `view` aceitasse configuração via um `ViewModel`. Nesse caso teríamos um protocolo para typos que possuem um `model`:

 
{% highlight swift %}
protocol HasModel {
    typealias Model
    var model: Model { get set }
}
{% endhighlight %}

Aqui temos um protocolo que possui um tipo associado ([Associated Type](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Generics.html)), isso significa que o tipo da propriedade `model` pode ser diferente para cada tipo que adotar esse protocol. Entretanto isso tem alguns [efeitos colaterais](http://www.russbishop.net/swift-associated-types) não relevantes para o exemplo corrente.

Vamos supor que eu não queira acessar a `customView `, mas passar o *view model* diretamente para a célula, como o modelo depende de cada view nossa célula vai passar a ter dois parâmetros, `View` e `ViewModel`. Essa classe então ficaria:

{% highlight swift %}
class CollectionViewCell<View: UIView, ViewModel where View: HasModel, View.Model == ViewModel>: UICollectionViewCell {

    private(set) var customView: View

    override init(frame: CGRect)
    {
        customView = View()

        super.init(frame: frame)
        contentView.addSubview(customView)

        customView.frame = contentView.bounds
        customView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    }

    var model: ViewModel {
        get {
            return customView.model
        }

        set(newModel) {
            customView.model = newModel
        }
    }
}
{% endhighlight %}

Agora a coisa fica mais interessante, note a definição do *generics* `<View: UIView, ViewModel where View: HasModel, View.Model == ViewModel>`. Ele define um tipo `View` que é subclasse de `UIView` e um tipo `ViewModel`, o `where` aplica restrições a esse tipos, o `View` adota o `HasModel` e o tipo associado `Model` da `View` é o mesmo do `ViewModel`.

Isso é suficiente para que qualquer `UIView` que adote o `HasModel` seja usada em uma *collection view*. Vamos supor que eu queira usar um `UILabel` para isso, uma *extension* de poucas linhas isso está resolvido:


{% highlight swift %}
extension UILabel: HasModel {

    var model: String {
        get {
            return text ?? ""
        }
        set(newModel) {
            text = newModel
            textAlignment = .Center
        }
    }
}
{% endhighlight %}

Para usar isso numa *collection view* precisamos primeiro registrar a classe da célula genérica (no `viewDidLoad` por exemplo):

{% highlight swift %}
collectionView.registerClass(CollectionViewCell<UILabel, String>.self, forCellWithReuseIdentifier: reuseIdentifier)
{% endhighlight %}

E então configurar a célula:

{% highlight swift %}
func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
{
    let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath)

    if let cell = cell as? CollectionViewCell<UILabel, String> {
        let max = collectionView.numberOfItemsInSection(indexPath.section)
        cell.model = "Cell \(indexPath.row+1)/\(max)"
    }

    return cell
}
{% endhighlight %}

Um exemplo completo pode ser encontrado no repositório [GenericCollectionViewCell](https://github.com/diogot/GenericCollectionViewCell). Criticas, sugestões e comentários são sempre bem vindos, é só me *pingar* no [@diogot](https://twitter.com/diogot) ou no [slack do iOS Dev BR](http://iosdevbr.herokuapp.com).

---
Diogo Tridapalli <br />
[@diogot](https://twitter.com/diogot)
