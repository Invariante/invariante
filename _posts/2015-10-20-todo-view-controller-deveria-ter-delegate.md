---
layout: post
title: Todo View Controller deveria ter um delegate
---

Qualquer pessoa que frequente o *slack* do [iOS Dev BR](http://iosdevbr.herokuapp.com) sabe que ando insatisfeito com `Storyboard`. Os motivos são vários mas hoje vou falar apenas de um, as `segues`. 

As `segues` facilitam a visualização do fluxo do *app* para uma pessoa que não está habituada com o projeto. É só abrir o `storyboard` (ou `storyboards`) e está tudo lá, todas as *setinhas* ligando seus *controllers*. Ai você me pergunta: *"Mas isso é lindo, porque te incomoda?"*. 

{% highlight objective-c %}
[self performSegueWithIdentifier:@"Segue" sender:result];
{% endhighlight %}

O que você acha desse trecho de código? Não me refiro a aquela bela *string* *mágica*, mas **onde** essa linha normalmente fica. Essa instrução está contida no `controller A` e é executada quando o mesmo terminou seu propósito e o `controller B` deve ser instanciado para continuar o fluxo.

Isso implica que o `controller A` tem algum conhecimento do que deve acontecer depois dele, se eu quiser trocar o `controller B` por um `controller C` eu poderia manter o nome da `segue` e fazer a alteração somente no `storyboard`, isso seria deselegante mas não um problema. Agora imagine que  o *controller* a ser instanciado a seguir dependa de algum resultado anterior a `segue`, quem deve decidir qual `segue` deve ser chamada? Na grande maioria dos códigos que vi (talvez não sejam tantos assim) o próprio `controller A` é responsável por tomar essa decisão. Isso não me cheira bem (vulgo [code smell](https://en.wikipedia.org/wiki/Code_smell)), mas vamos continuar...

Bom, em qualquer app, alguma hora, você vai precisar passar informação entre os *controllers* e como você faz isso?

{% highlight objective-c %}
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"SegueB"]) {
        MYControllerB *controller = segue.destinationViewController;
        controller.propertyB = sender;
    } else if ([segue.identifier isEqualToString:@"SegueC"]) {
        MYControllerC *controller = segue.destinationViewController;
        controller.propertyC = sender;
    }
}
{% endhighlight %}

Se antes não estava cheirando bem, agora o cheiro está pior que  o Rio Pinheiros ali na estação Vila Olímpia! As *strings* *mágicas* continuam por aí, temos um `sender` que pode ser qualquer coisa e, por último mas o pior de todos, o `controller A` *sabe* sobre o `controller B` e `controller C`. *"Mas porque isso é tão ruim?"* Esse acoplamento dificulta muito a substituição de qualquer uma das três classes, faz com que seja muito mais complexo para testar essa classe pois não há como fazer injeção de dependência ([Dependency Injection](https://en.wikipedia.org/wiki/Dependency_injection)) e esse `if else if ...` interminável é deselegante (sim, eu sei que em *Swift* seria um `switch` menos deselegante).

Depois de todo esse discurso *anti-*`Storyboard` imagino os defensores dessa *"tecnologia"* estejam incomodados, para eles tenho duas coisas a dizer: Primeiro eu acredito que existem situações em que `Storyboards` são adequados, projetos grandes e que vão durar muitos anos não se enquadram nessas situações (estou disposto a discutir esse assunto em uma outra ocasião); Segundo, fazendo a transição de *controllers* sem `segue` vemos o mesmo acoplamento:

{% highlight objective-c %}
if (something) {
    MYControllerB *controller = [[MYControllerB alloc] initWithThing:aThing];
    [self.navigationController pushViewController:controller animated:YES];
} else if (otherthing) {
    MYControllerC *controller = [[MYControllerC alloc] initWithThing:aThing2];
    [self presentViewController:controller animated:YES completion:nil];
}
{% endhighlight %}

Nesse caso algo ruim que era resolvido pelo `segue` acontece, o `controller A` tem a responsabilidade de escolher como os outros *controllers* serão apresentados e ainda esperar que ele próprio esteja dentro de um `UINavigationController`, nada bom.

Existe um conceito chamado de *Princípio de responsabilidade única* (não sei se essa seria a tradução mais adequada, [Single responsibility principle](https://en.wikipedia.org/wiki/Single_responsibility_principle)), ele diz cada classe deve ter apenas uma responsabilidade ou, como diria o [Agent Smith](https://en.wikipedia.org/wiki/Agent_Smith), um **propósito**. Imaginemos que o `controller A` tenha o propósito de obter a idade do usuário, então dele deve ser criado quando o *app* precisar obter essa informação e a única coisa que o *controller* precisa fazer é obter esse informação. Não faz parte do propósito dele ter conhecimento (*importar*) classes que não tenham relação direta com seu propósito, em particular, classes que venham antes ou depois dele no fluxo. Muito menos **decidir**, com base nessa informação, qual seria o próximo passo no fluxo do *app*, **instanciar** o próximo controller e passar a informação para ele, **decidir** como esse controller será apresentado e **apresentá-lo**. 

Esse é um problema que vem me incomodando faz algum tempo, há um ano li um artigo falando sobre [Flow Controllers](http://albertodebortoli.github.io/blog/2014/09/03/flow-controllers-on-ios-for-a-better-navigation-control/), achei interessante, ele resolve o problema da injeção de dependência, mas o *controller* ainda tem a responsabilidade de dizer qual é o próximo passo no fluxo do *app* e eu acredito que isso não faz parte do propósito dele.

Uma possível solução para isso é postular que:

* Todo `view controller` tem que ter um `delegate`;
* Um `view controller` não deve usar referências a `parentViewController`, `navigationController`, `tabBarController`, `splitViewControoler`, ou `presentingViewController` ou qualquer outro *parent controller* que inventarem;
* Um `view controller` só pode fazer (`#include`) de outros `view controllers` se esses forem necessários para cumprir seu propósito;
* Quando um `view controller` completar seu propósito ele notifica seu `delegate` e esse é responsável por continuar o fluxo;
* Um `view controller` nunca deve usar `segues`, isso não faz parte do seu propósito.

Uma maneira de satisfazer essas condições é ter uma classe que é `delegate` de todos os `view controllers`, que sabe instanciar todos os `view controller` e inclusive quais modelos são necessários para isso. Isso não me cheira muito bem, mas é melhor que antes. Como ainda é uma das primeiras interações alguma hora deve aparecer alguma idéia (aceito sugestões).

Penso que esse `delegate` deve ser o primeiro `controller` do *app*, por exemplo, uma subclasse do `UINavigationController`.
Essa abordagem tem algumas vantagens:

* Pode ser uma maneira de começar a migrar um *app* para `Swift` pois, normalmente, a essa *controller* inicial é padrão e não tem muita interação com outros *controllers*. Além disso os novos *controllers* irão interagir somente com esse, além dos modelos e a camada de rede;
* Todo o fluxo do *app* fica em apenas uma classe e não espalhado por vários lugares;
* Como o *delegate* sabe instanciar todos os *controllers*, ele pode receber o *roteamento* vindo de *deep links* ou `NSUserActivity` sem dificuldade;
* Se você quiser fazer uma classe especial para mostrar notificações ou `popups` personalizados, o delegate seria o cara ideal para gerenciar quando e como eles devem ser apresentados.

Um exemplo pode deixar as coisas mais claras. Um *app* tem dois *view controllers*. O responsável pelo primeira tela (`DTRootViewController`) em `Objective-c`, o propósito dele é obter do usuário um texto, sua interface seria:

{% highlight objective-c %}
@interface DTRootViewController : UIViewController

@property (nonatomic, weak) id<DTRootViewControllerDelegate> delegate;

@end

@protocol DTRootViewControllerDelegate <ViewControllerDelegate>

- (void)didSelectedText:(nullable NSString *)text
   onRootViewController:(nonnull DTRootViewController *)controller;

@end
{% endhighlight %}

O segundo *view controller*, em `Swift`, (`OtherViewController`) tem como propósito mostrar um texto, e  sua interface pública seria:

{% highlight swift %}
protocol OtherViewControllerDelegate : ViewControllerDelegate 
{
    func shouldDismissOtherViewController(controller: OtherViewController)
}

class OtherViewController : UIViewController
{
    init(text: NSString, navigationCloseButton: Bool, delegate: OtherViewControllerDelegate?)
}
{% endhighlight %}

O *view controller* primário desse *app* (`NavigationController`) é uma subclasse do `UINavigationController` (também em `Swift`) e sua implementação seria:

{% highlight swift %}
class NavigationController: UINavigationController, DTRootViewControllerDelegate, OtherViewControllerDelegate
{
    override func awakeFromNib()
    {
        let controller = DTRootViewController()
        controller.delegate = self
        self.setViewControllers([controller], animated: false)
    }

    // MARK: DTRootViewController

    func didSelectedText(text: String?, onRootViewController controller: DTRootViewController)
    {
        if let text = text {
            self.presentOtherViewControllerWithText(text)
        } else {
            print("do nothing")
        }
    }

    // MARK: OtherViewController

    func presentOtherViewControllerWithText(text: String)
    {
        if text.localizedCaseInsensitiveContainsString("modal") {
            let controller = OtherViewController(text: text, navigationCloseButton: true, delegate: self)
            self.presentViewControllerWithNavigationController(controller, animated: true)
        } else if text.localizedCaseInsensitiveContainsString("push") {
            let controller = OtherViewController(text: text, navigationCloseButton: false, delegate: nil)
            self.pushViewController(controller, animated: true)
        }
    }

    func shouldDismissOtherViewController(controller: OtherViewController)
    {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    // MARK:
    func presentViewControllerWithNavigationController(controller: UIViewController,
                                                         animated: Bool)
    {
        let navigation = UINavigationController(rootViewController: controller)
        self.presentViewController(navigation, animated: animated, completion: nil)
    }
}
{% endhighlight %}

O projeto completo se encontra no [github](https://github.com/diogot/ViewControllerDelegate), mas olhando apenas a implementação do `NavigationController` vemos que toda a lógica de fluxo de app está contida em apenas uma classe, dessa forma é possível apresentar o `OtherViewController ` tanto *modalmente* quanto dentro do *navigation controller* de maneira transparente, sem ter que alterar o *controller* apresentado.

Como eu disse anteriormente, eu ainda estou começando a utilizar essa abordagem e novos problemas e dificuldades devem aparecer com o uso. Minha intenção e fazer outros artigos sobre esse assunto conforme eu for desenvolvendo o tema, críticas, comentários e sugestões são bem vindos, o [Twitter](https://twitter.com/diogot) e o [slack do iOS Dev BR](http://iosdevbr.herokuapp.com) são os canais mais fáceis.

---

*Update 2015/10/20 13h:* O [Igor](https://twitter.com/icastanheda) levantou um ponto que eu não tinha pensado, é possível se livrar sem grande dificuldade do acoplamento no `prepareForSegue:sender:` usando uma subclasse da `UIStoryboardSegue`, fazendo o acoplamento do `controller A` com o `controller B` dentro dessa classe. Acho uma solução bem razoável.

*Update 2015/10/20 23h:* O [Fabri](https://twitter.com/marcelofabri_) comentou que existem várias iniciativas como o [Natalie](https://github.com/krzyzanowskim/Natalie) para resolver o problema das *strings mágicas*, acho válido, mas preferia que houvesse alguma coisa nativa.

*Update 2014/11/22* O [Tales](https://twitter.com/talesp) apontou um ponto importante, nem sempre é possível usar um `delegate`. Por exemplo quando o *view controller* é subclasse de `UITableViewController`. Casos em que um `delegate` não é conveniente seria melhor usar propriedades que contém blocos que são chamados no lugar dos métodos do protocolo do `delegate`. Nada impede que as duas maneiras sejam implementadas.

---

Como o **Invariante** foi citado no **Podcast do CocoaHeads Brasil**, acho justo retribuir a gentileza ;-)

Essa semana saiu a terceira edição do Podcast semanal do CocoaHeads Brasil, nessa edição [eu](https://twitter.com/diogot), [Bruno Koga](https://twitter.com/brunokoga), [Douglas Fischer](https://twitter.com/DougDiskin) e [Tales Pinheiro](https://twitter.com/talesp) conversamos sobre as novidades do iOS 9, o podcast está disponível no
[iTunes](https://itunes.apple.com/br/podcast/cocoaheads-brasil/id1044808957?l=en&mt=2) e no [SoundCloud](https://soundcloud.com/cocoaheadsbr/s01e02-novidades-do-ios9).

---
Diogo Tridapalli <br />
[@diogot](https://twitter.com/diogot)
