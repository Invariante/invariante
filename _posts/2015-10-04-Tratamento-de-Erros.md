---
layout: post
title: Tratamento de Erros em Swift
---

Uma das grandes novidades do Swift 2 foi o suporte para tratamento de erros (em inglês, *error handling*).

Mas o que isso quer dizer?

Algumas operações (geralmente funções) não oferecem a garantia de completar sua execução ou mesmo de produzir um retorno útil. Em Swift, usamos *optionals* para representar uma ausência de valor (`nil`). Porém, quando uma função retorna `nil` pode ter acontecido um erro e, muitas vezes, queremos entender o que causou este erro, para que nosso programa possa responder de acordo. É importante diferenciar as diversas formas que uma operação pode falhar e comunicar ao usuário adequadamente.

A forma mais comum de resolver o problema de tratamentos de erros com Objective-C é passar uma variável adicional de erro no método e, caso haja algum erro, o método fica responsável por popular essa variável com o objeto de erro, além de retornar `nil`.

Essa abordagem é confusa e não intuitiva. Esse é um exemplo comum em Objective-C:

{% highlight swift linenos %}
NSString *path = @"..."; // caminho para um arquivo
NSError *error;
NSData *data = [NSData dataWithContentsOfFile:path options:NULL error: &error];
{% endhighlight %}

O problema aqui é que não temos informações claras sobre a relação entre o retorno `data` e o erro `error`. Se `data` for `nil` isso significa que `error` é não-`nil`? E se `data` for um objeto `NSData` válido, significa que `error` vai ser sempre `nil`? Existe algum caso em que ambos `data` e `error` são populados? Existe algum caso em que ambos `data` e `error` são `nil`?

Uma forma ingênua de resolver o problema em Swift de maneira similar (e carregar os mesmos efeitos colaterais da abordagem) seria termos funções que retornam uma tupla:

{% highlight swift linenos %}
func dataWithContentsOfFile(path: String) -> (NSData?, NSError?) { ... }
{% endhighlight %}

Aqui, novamente, não existe relação entre os valores retornados na tupla e, pior, como precisamos retornar `optionals` (afinal, os valores podem ser nulos), o código fica totalmente deselegante.


## E agora?

O Swift 2 resolve o problema introduzindo uma sintaxe adequada para o tratamento de erros. 

Para os exemplos desse artigo, vamos criar uma camada de abstração sobre o [AddressBook](https://developer.apple.com/library/prerelease/ios/documentation/AddressBook/Reference/AddressBook_iPhoneOS_Framework/). Apesar de muitas das funcionalidades do AddressBook terem sido *deprecated* no iOS 9 (graças ao [Contacts Framwork](https://developer.apple.com/library/prerelease/ios/documentation/Contacts/Reference/Contacts_Framework/index.html#//apple_ref/doc/uid/TP40015328)), ele ainda é importante para apps que suportam acesso aos contatos no iOS 8. A idéia dessa camada é, exatamente, facilitar a transição para o `Contacts Framework` no futuro, minimizando o impacto no nosso código.

Primeiramente, vamos falar sobre o protocolo `ErrorType`. Ele é declarado na biblioteca padrão do Swift da seguinte forma:

{% highlight swift linenos %}
public protocol ErrorType {
}
{% endhighlight %}

Isso mesmo. Ele é um protocolo vazio. Isso quer dizer que qualquer tipo de dado pode ser usado para representar um erro.

Em Swift, a melhor forma de representar erros é com *enums* (adotando o protocolo `ErrorType`). É importante lembrar que podemos passar valores associados a esses enums, possibilitando adicionar alguma informação relevante sobre a natureza do erro. Nesse artigo, porém, não falaremos de valores associados.

Para o nosso exemplo, temos a seguinte *struct*, que representará a nossa camada sobre o AddressBook. O importante aqui é saber que essa *struct* pode ser inicializada tanto passando um `ABAddressBook` como parâmetro ou inicializar com o `ABAddressBook` padrão:

{% highlight swift linenos %}
public struct AddressBookPermission {
    
    private let addressBookRef: ABAddressBook?

    public init() {
        let unmanagedAddressBookRef = ABAddressBookCreateWithOptions(nil, nil)
        if let addressBookRef = unmanagedAddressBookRef {
            self.addressBookRef = addressBookRef.takeRetainedValue()
        } else {
            addressBookRef = nil
        }
    }
    
    public init(addressBookRef: ABAddressBookRef) {
        self.addressBookRef = addressBookRef
    }
}
{% endhighlight %}

E, para representar nossos erros, vamos declarar o seguinte enum (dentro de uma extension de `AddressBookPermission`):

{% highlight swift linenos %}
public extension AddressBookPermission {
    public enum Error: ErrorType {
        case NotAuthorized
        case ContactCouldNotBeCreated
    }
}
{% endhighlight %}

Agora, vamos criar uma função no nosso `AddressBookPermission` onde recebemos um `CFData` contendo o vCard a ser adicionado ao *Address Book* e retornamos um array de Strings com os IDs adicionados:

{% highlight swift linenos %}
public func addContactsFromVcard(vCardData: CFData) -> [String] { ... }
{% endhighlight %}

Note que o retorno da nossa função **não** é um *optional*, ou seja, nós garantimos que vamos retornar um Array de Strings (nem que ele seja vazio). Mas nossa função pode não conseguir completar a sua tarefa e se deparar com algum erro no seu caminho. Além disso, queremos determinar de forma clara a diferença entre retornar um Array vazio (ou seja, não havia nenhum contato no vCard) ou "retornar" um erro (ou seja, alguma coisa realmente deu errado).

Para isso, vamos adicionar o *keyword* `throws` na nossa função. Como somos bons cidadãos, também vamos documentar (uso o [VVDocumenter](https://github.com/onevcat/VVDocumenter-Xcode) para isso):

{% highlight swift linenos %}
/**
    Adds contacts (in form of vCard data) to the Address Book.
    
    - parameter vCardData: The vCardData to be added.
    
    - throws: AddressBookPermissionError.NotAuthorized if the user has denied access to the Address Book.
    
    	AddressBookPermissionError.ContactCouldNotBeCreated contact couldn't not be created for any other reason.
    
    - returns: the new Contact IDs as a [String]
    */
    
	public func addContactsFromVcard(vCardData: CFData) throws -> [String] { ... }
{% endhighlight %}

Nota: como utilizamos a sintaxe do Swift para documentação, é assim que vemos nossos comentários ao clicarmos com ⌥+click na chamada na nossa função:

<img src="/public/imgs/error-handling-1.png" alt="Boa documentação <3" style="width: 100%; margin 0 auto 0 auto;"/>

A declaração da nossa função agora diz que ela retorna um Array de Strings, mas, **ao invés disso** ela pode terminar a execução no meio e jogar um  erro.

Nesse caso, existem dois tipos de erros que nos interessa: ou o usuário não deu permissão para acessar o Address Book (.NotAuthorized) ou o contato não pôde ser criado por qualquer outro motivo (falta de espaço em disco, dados corrompidos, etc: .ContactCouldNotBeCreated). Esse é o corpo da nossa função (não se assuste com as chamadas C-style da API do `ABAddressBook`):


{% highlight swift linenos %}
/**
    Adds contacts (in form of vCard data) to the Address Book.
    
    - parameter vCardData: The vCardData to be added.
    
    - throws: AddressBookPermissionError.NotAuthorized if the user has denied access to the Address Book.
    
        AddressBookPermissionError.ContactCouldNotBeCreated contact couldn't not be created for any other reason.
    
    - returns: the new Contact IDs as a [String]
    */
    public func addContactsFromVcard(vCardData: CFData) throws -> [String] {
        if authorizationStatus() != .Authorized {
            throw Error.NotAuthorized
        }
        
        var contactIds: [String] = []
        let defaultSource = ABAddressBookCopyDefaultSource(addressBookRef).takeRetainedValue()
        let vCardPeople = ABPersonCreatePeopleInSourceWithVCardRepresentation(defaultSource, vCardData).takeRetainedValue() as [ABRecord]
        
        for person in vCardPeople {
            var addRecordError: Unmanaged<CFError>? = nil
            if ABAddressBookAddRecord(addressBookRef, person, &addRecordError) {
                let recordId = ABRecordGetRecordID(person)
                let contactIdString = String(recordId)
                contactIds.append(contactIdString)
            } else {
                if let error = addRecordError?.takeRetainedValue() as NSError? {
                    ABAddressBookRevert(addressBookRef)
                    switch error.code {
                    case kABOperationNotPermittedByUserError:
                        throw Error.NotAuthorized
                    case kABOperationNotPermittedByStoreError:
                        fallthrough
                    default:
                        throw Error.ContactCouldNotBeCreated
                    }
                } else {
                    throw Error.ContactCouldNotBeCreated
                }
            }
        }
        
        ABAddressBookSave(addressBookRef, nil);
        
        return contactIds
    }
{% endhighlight %}

Nas duas primeiras linhas, checamos se estamos autorizados a acessar o Address Book. Essa é a implementação da função `authorizationStatus()`: 

{% highlight swift linenos %}
/**
    Checks our current ABAuthorizationStatus.
    
    - returns: The current ABAuthorizationStatus
    */
    private func authorizationStatus() -> ABAuthorizationStatus {
        let authorizationStatus = ABAddressBookGetAuthorizationStatus()
        return authorizationStatus
    }
   
{% endhighlight %}

Se não tivermos acesso, nós jogamos um erro. Nesse caso, a execução da função é encerrada (e não há retorno!). Caso contrário, continuamos a execução. Utilizamos a API do `ABAddressBook` para criar um array de `ABRecord` a partir do nosso vCard (um vCard pode ter mais de um contato). A partir daí iteramos sobre esse Array, criando os contatos no nosso AddressBook. Na implementação apresentada, se tivermos *qualquer erro* durante esse processo, nós revertemos o AddressBook para o estado inicial e jogamos o erro apropriado (fazendo um mapeamento dos `CFError` criados pela função `ABAddressBookAddRecord` para `ErrorType`). Caso tudo ocorra bem, salvamos o AddressBook e retornamos o Array de IDs (String) criados.

## Ok, entendi. Mas como uso isso agora?

Bom, agora vamos criar o código que vai utilizar nossa função. Se tentarmos escrever algo assim:

{% highlight swift linenos %}
let permission = AddressBookPermission()
let urlPath = NSBundle.mainBundle().pathForResource("vcard", ofType: "vcf")
if let urlPath = urlPath {
	if let vCardData = NSData(contentsOfFile: urlPath) {
		permission.addContactsFromVcard(vCardData) //ignoramos o return
	}
}
{% endhighlight %}

O compilador nos dará o erro "Call can throw, but it is not marked with 'try' and the error is not handled".

<img src="/public/imgs/error-handling-2.png" alt="Cadê o try?" style="width: 100%; margin 0 auto 0 auto;"/>

## Faça, tente, capture.

Existem quatro formas de tratar erros em Swift. Você pode propagar o erro, tratar o erro com `do-catch`, tratar o erro como um valor opcional ou, caso você pode forçar a chamada sem tratar o erro (e, caso o erro ocorra, você terá um crash, similar a forçar um desempacotamento de opcional quando ele é `nil`).

É importante lembrar que quando uma função lança um erro (lançar = *throw*), o fluxo do seu programa sofre uma alteração. É importante identificar e tratar corretamente os lugares onde erros podem ser lançados.

### Propagar

No nosso exemplo, se quisermos simplesmente propagar o erro, podemos encapsular o nosso código em uma função e declarar que ela também lança (*throw*) um erro. Além disso, precisamos marcar a(s) chamada(s) que podem lançar erros com `try`:

{% highlight swift linenos %}
func addContacts() throws {
    let permission = AddressBookPermission()
    let urlPath = NSBundle.mainBundle().pathForResource("vcard", ofType: "vcf")
    if let urlPath = urlPath {
        if let vCardData = NSData(contentsOfFile: urlPath) {
            try permission.addContactsFromVcard(vCardData) //ignoramos o return
        }
    }
}
{% endhighlight %}

### Tratar o erro com do-catch

Você pode tratar um erro diretamente usando o `do-catch`. Basicamente, você encapsula o código que pode lançar um erro dentro de um escopo `do`, marca as chamadas pra funções que lançam erro com `try` e captura os erros com `catch`:

{% highlight swift linenos %}
let permission = AddressBookPermission()
let urlPath = NSBundle.mainBundle().pathForResource("vcard", ofType: "vcf")
if let urlPath = urlPath {
	if let vCardData = NSData(contentsOfFile: urlPath) {
		do {
			let ids = try permission.addContactsFromVcard(vCardData)
		} catch AddressBookPermission.Error.NotAuthorized {
		// Mostra um alert dizendo que não temos permissão e mostrando como dar permissão de acesso à agenda.
		} catch AddressBookPermission.Error.ContactCouldNotBeCreated {
		// Mostra um alert de que algo deu errado, mas que não sabemos exatamente o motivo.
		}
	}
}
{% endhighlight %}

Note que **não** precisamos ter uma cláusula `catch` para cada erro que possa ser lançado. Ao invés disso, podemos ter uma cláusula `catch` que captura todos os demais erros (semelhante a um `default` no `switch`) ou até mesmo tratar alguns erros e propagar outros (para isso, precisaríamos marcar nossa função com `throws` novamente). Veja os exemplos:

Aqui, capturamos todos os erros e tratamos da mesma forma:

{% highlight swift linenos %}
let permission = AddressBookPermission()
let urlPath = NSBundle.mainBundle().pathForResource("vcard", ofType: "vcf")
if let urlPath = urlPath {
	if let vCardData = NSData(contentsOfFile: urlPath) {
		do {
			let ids = try permission.addContactsFromVcard(vCardData)
		} catch {
		// Aqui capturamos todos os erros da mesma forma.
		}
	}
}
{% endhighlight %}

Aqui, tratamos um tipo de erro, mas propagamos os outros:

{% highlight swift linenos %}
func addContacts() throws {
    let permission = AddressBookPermission()
    let urlPath = NSBundle.mainBundle().pathForResource("vcard", ofType: "vcf")
    if let urlPath = urlPath {
    	do {
			let ids = try permission.addContactsFromVcard(vCardData)
		} catch AddressBookPermission.Error.NotAuthorized {
			// Tratamos esse caso
		}
	}
}

{% endhighlight %}

### Converter erros para valores opcionais

Você pode usar a sintaxe `try?` para tratar o erro convertendo ele para um valor opcional. Isso quer dizer que, se um erro for lançado durante uma expressão marcada com `try?`, o valor da expressão será `nil` (porém, você vai perder qualquer informação relacionada ao erro lançado, uma vez que usando `try?` você abdica da capacidade de capturar o erro. Nosso código ficaria assim:

{% highlight swift linenos %}
let ids = try? permission.addContactsFromVcard(vCardData)
{% endhighlight %}

Caso um erro seja lançado, o valor de `ids` será `nil`.

### Forçar "não-erro"

Seja porque você tem certeza que uma função não vai lançar um erro ou seja por pura displicência, você pode também usar a seguinte sintaxe para desabilitar completamente a propagação de erros. Note que, usando essa sintaxe, caso um erro seja lançado, você vai ter um erro de tempo de execução (e, claro, um crash):

{% highlight swift linenos %}
try! permission.addContactsFromVcard(vCardData)
{% endhighlight %}

### Defer

Quando você declara uma função que pode lançar um erro, você pode usar o `defer` para executar comandos momentos antes da execução do código deixar o bloco de código atual. O `defer` é muito útil para garantir que um um certo código irá rodar independentemente de como o seu código terminou a execução (seja por um `return`, `throw`, ou `break`). Caso você tenha múltiplos `defer`, os códigos dentro de `defer` são executados na ordem inversa da qual eles são declarados, ou seja, o código no primeiro `defer` vai rodar depois do código no segundo `defer` e assim por diante. Veja esse exemplo retirado do [Swift Programming Language](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/ErrorHandling.html). Nesse código, o `defer` garante que o arquivo será fechado:

{% highlight swift linenos %}
func processFile(filename: String) throws {
    if exists(filename) {
        let file = open(filename)
        defer {
            close(file)
        }
        while let line = try file.readline() {
            // Work with the file.
        }
        // close(file) is called here, at the end of the scope.
    }
}
{% endhighlight %}

## Isso é importante mesmo?

Apesar do Swift 2 ser recente,  já existem muitos artigos e exemplos sobre tratamentos de erros em Swift. Além disso, com a promessa do Swift ter seu código aberto até o fim do ano, entender todas as capacidades da linguagem, o seu funcionamento e sua biblioteca padrão podem ser importantes mesmo se você não desenvolve ou não tem planos para desenvolver especificamente para o ecossistema da Apple. E tratamento de erros está enraizado tanto na filosofia como nas boas práticas do Swift.

---
Bruno Koga <br />
[@brunokoga](http://twitter.com/brunokoga)
