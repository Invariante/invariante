---
layout: post
title: Storyboards e Injeções de Dependências.
---

##Eu sou fã de Storyboards.

Acho a discussão "Storyboards versus UI programaticamente" totalmente válida. É importante entender que existem duas (ou até mais) formas diferentes de resolver os mesmos problemas. Sempre gostei da forma que XIBs e Storyboards facilitam e agilizam o desenvolvimento de views e view controllers. Além disso, acho que são ferramentas insubstituíveis para o aprendizado de alguns conceitos do UIKit.

Assim como em código, você precisa saber o que está fazendo ao usar um Storyboard. O propósito do Storyboard é você simplificar um fluxo de view controllers que estão interconectadas. Como o meu caro amigo Diogo apontou no [último post do Invariante](http://invariante.com/2015/10/20/todo-view-controller-deveria-ter-delegate/), ao usar Storyboards você acaba acoplando o seu código, pois de uma forma ou outra suas view controllers vão saber da existência uma das outras. Mas será que isso é tão ruim assim quando você está falando de um Storyboard que representa um fluxo atômico no seu app (um fluxo de cadastro ou de tutorial, por exemplo) onde realmente não existe uma complexidade que justifique esse isolamento entre suas view controllers? Para mim, faz parte do _toolset_ de um bom desenvolvedor iOS saber desenvolver fluxos simples e prototipar utilizando Storyboards.

E existem também os (vários) casos em que Storyboards atrapalham mais do que ajudam. O modo como os Storyboards são implementados no UIKit fazem com que muitas vezes ele nos force a usar [anti-patterns](https://en.wikipedia.org/wiki/Anti-pattern) como [God Object](https://en.wikipedia.org/wiki/God_object) (onde um objeto sabe ou faz muito, violando o [Princípio de Responsabilidade Única](https://en.wikipedia.org/wiki/Single_responsibility_principle)), [Magic Strings](https://en.wikipedia.org/wiki/Magic_string#Magic_strings_in_code), ou [BaseBean](https://en.wikipedia.org/wiki/BaseBean) (forçar herança ao invés de delegação). Os Storyboards também são (justamente) conhecidos por aumentar o acoplamento do seu código, dificultando [injeções de dependências](https://pt.wikipedia.org/wiki/Injeção_de_dependência).

##O que é Injeção de Dependências mesmo?
O conceito de Injeção de Dependências pode ser difícil de se entender para desenvolvedores com pouca experiência, principalmente quando se está começando a programar (e muitas vezes é esquecido em projetos reais). Uma explicação simples seria mais ou menos assim:

Teoricamente, você quer sempre deixar o seu código com o menor nível de acoplamento possível. Isso significa que cada módulo do seu sistema deve saber o mínimo possível sobre os outros módulos existentes para cumprir a sua funcionalidade. Injetar dependências signfica que cada módulo, ao ser criado, terá suas dependências configuradas por outro módulo do sistema, mantendo assim um baixo acoplamento.
	
##Exemplo usando Storyboard

Para ilustrar, temos o app abaixo, onde há um tela que busca uma imagem na internet e apresenta para usuário. A idéia é que o `FetchAndDisplayImageViewController` consiga buscar uma imagem através do `FetchImageService` e mostrar na sua `imageView`.

<img src="/public/imgs/euamostoryboard-1.png" alt="Storyboard do projeto<3" style="width: 100%; margin 0 auto 0 auto;"/>

Em uma implementação mais ingênua do `FetchAndDisplayImageViewController` teríamos algo assim:

{% highlight swift linenos %}
class FetchAndDisplayImageViewController: UIViewController {

    //Image Service to fetch the image to display
    var imageService: FetchImageService?
    
    //Image View utilizada para mostrar a imagem
    @IBOutlet weak var imageView: UIImageView!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        imageService = FetchImageService(param1: "Invariante", param2: "Rocks")
        if let imageService = imageService {
            imageView.image = imageService.fetchImage()
        }
    }
}
{% endhighlight %}

Acredito que seja fácil de perceber que essa implementação é, no mínimo, questionável, pois o `FetchAndDisplayImageViewController` sabe como instanciar o `FetchImageService`. Isso deixa o nosso código mais amarrado e faz com que nossa `FetchAndDisplayImageViewController` seja praticamente impossível de ser testada. Uma solução melhor é apresentada abaixo. Num post futuro mostrarei porque esse maior acoplamento (e a falta de injeção de dependência) torna o nosso código menos testável.

{% highlight swift linenos %}
class FetchAndDisplayImageViewController: UIViewController {

    //Image Service to fetch the image to display
    var imageService: FetchImageService?
    
    //Image View utilizada para mostrar a imagem
    @IBOutlet weak var imageView: UIImageView!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Esperamos que alguém externo tenha configurado nossa dependência:
        if let imageService = imageService {
            imageView.image = imageService.fetchImage()
        } else {
            print("Não era para isso acontecer...")
        }
    }
}
{% endhighlight %}
Desta forma, nós não instanciamos a nossa propriedade `imageService`, mas ao invés disso, no `viewDidLoad` esperamos que a propriedade `imageService` tenha sido configurada por alguém.

No post anterior o Diogo também comentou sobre a forma de se passar informações entre o nosso `ViewController` e o `FetchAndDisplayImageViewController` quando utilizamos Storyboards. Essa seria a forma correta de setar a propriedade `imageService` nessa abordagem:

{% highlight swift linenos %}
class ViewController: UIViewController {

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ViewControllerToFetchAndDisplayImageViewControllerSegue" {
            if let destinationViewController = segue.destinationViewController as? FetchAndDisplayImageViewController {
                let imageService = FetchImageService(param1: "Invariante", param2: "Rocks")
                destinationViewController.imageService = imageService
            }
        }
    }
}
{% endhighlight %}

E é aí que o Storyboard mostra sua fragilidade. Quantos problemas você consegue ver nos dois últimos trechos de código acima? Eu consigo citar alguns:
 
1) A property `imageService` é uma _var_. Gostaríamos muito que ela fosse imutável (_let_). Para isso precisaríamos setá-la no _init_ (e, por estarmos utilizando Storyboards, não temos como fazer isso);

2) Essa mesma propriedade precisa ser _public_ ou _internal_ pois ela é setada por outra classe (ViewController). Idealmente, queremos que ela seja _private_;

3) Além disso, `imageService` precisa ser um optional, o que acaba deixando o código mais verboso, pois precisamos sempre fazer o unwrap dessa variável ao usá-la;

4) Por ser possível apresentar a `FetchAndDisplayImageViewController` sem setar a _var_ `imageService`, precisamos definir o comportamento da view controller caso isso aconteça.

Que bagunça! E como a gente pode melhorar isso? Simples: não use Storyboards :)

##Exemplo em código

Veja que no código abaixo, agora é mandatório que o `imageService` seja passado na inicialização da nossa classe. Assim, conseguimos fazer que a nossa propriedade `imageService` seja privada e imutável (e, claro, não-opcional).

{% highlight swift linenos %}
class FetchAndDisplayImageViewController: UIViewController {

    //Image Service to fetch the image to display
    //Note que agora nossa propriedade é imutável (let), além de ser privada.
    private let imageService: FetchImageService
    
    //Image View utilizada para mostrar a imagem
    weak var imageView: UIImageView!
    
    init(imageService: FetchImageService) {
        self.imageService = imageService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        
        imageView = UIImageView()
        //Adicionar constraints manualmente.
        
        view.addSubview(imageView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Sabemos que nossa dependência foi configurada no `init`
        imageView.image = imageService.fetchImage()
    }
}
{% endhighlight %}

##Entendi! Agora eu também odeio Storyboards!

Pode ter certeza que você não está sozinho, mas infelizmente não compartilho da mesma opinião. Como eu falei, sou fã de Storyboards e acho sim que eles tem um papel importantíssimo no desenvolvimento de apps. É importante saber discernir os momentos certos de utilizar ou não Storyboards. Não acredito que as abordagens acima utilizando Storyboards estejam **necessariamente** erradas. É tudo uma questão de saber o que está fazendo e escolher a ferramenta certa para cada problema.

---

Fique a vontade para discutir os artigos do _Invariante_ no [Slack do iOSDevBR](http://iosdevbr.herokuapp.com). Temos alguns canais como o _#general_, _#code-help_, _#learn_, _#swift_, entre outros. A galera lá está sempre disposta a ajudar e esclarecer dúvidas :)

---
Bruno Koga <br />
[@brunokoga](http://twitter.com/brunokoga)